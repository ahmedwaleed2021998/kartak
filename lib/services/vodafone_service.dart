import 'dart:convert';
import 'package:http/http.dart' as http;

/// نفس منطق السكريبت البايثون: كاش لحمو (1).py
class VodafoneService {
  static const _headers = {
    'User-Agent': 'okhttp/4.12.0',
    'x-agent-operatingsystem': '16',
    'clientId': 'AnaVodafoneAndroid',
    'Accept-Language': 'ar',
    'x-agent-device': 'Samsung SM-A165F',
    'x-agent-version': '2025.11.1',
    'x-agent-build': '1063',
    'digitalId': '',
    'device-id': 'b26ba335813fad21',
  };

  // الوحدات تحت الاسم (من العميل)
  static const units = {
    "Fakka_2.5_Unite": "45 وحدة • يوم",
    "Fakka_4.25_Unite": "190 وحدة • يوم",
    "Fakka_5_Unite": "80 وحدة • 2 يوم",
    "Fakka_6_NewUnite": "225 وحدة • 2 يوم",
    "Fakka_9_Unite": "400 وحدة • 4 أيام",
    "Fakka_10_Unite": "300 وحدة • 2 يوم",
    "Fakka_10.5_Unite": "400 وحدة • 6 أيام",
    "Fakka_12_Unite": "425 وحدة • 7 أيام",
    "Fakka_13.5_Unite": "625 وحدة • 7 أيام",
    "Fakka_20_Unite": "750 وحدة • 10 أيام",
  };

  static String getUnits(String productId) => units[productId] ?? "";

  // المنتجات - نفس PRODUCTS في البايثون
  static const products = [
    ("1", "فكة 2.5 جنيه", "Fakka_2.5_Unite"),
    ("2", "فكة 4.25 جنيه", "Fakka_4.25_Unite"),
    ("3", "فكة 5 جنيه", "Fakka_5_Unite"),
    ("4", "فكة 6 جنيه", "Fakka_6_NewUnite"),
    ("5", "فكة 7 جنيه", "Fakka_7_Unite"),
    ("6", "فكة 9 جنيه", "Fakka_9_Unite"),
    ("7", "فكة 10 جنيه", "Fakka_10_Unite"),
    ("8", "فكة 10 جنيه (جديد)", "Fakka_10_NewUnite"),
    ("9", "فكة 10.5 جنيه", "Fakka_10.5_Unite"),
    ("10", "فكة 11.5 جنيه", "Fakka_11.5_Unite"),
    ("11", "فكة 12 جنيه", "Fakka_12_Unite"),
    ("12", "فكة 12.5 جنيه", "Fakka_12.5_Unite"),
    ("13", "فكة 13 جنيه", "Fakka_13_Unite"),
    ("14", "فكة 13.5 جنيه", "Fakka_13.5_Unite"),
    ("15", "فكة 15 جنيه", "Fakka_15_Unite"),
    ("16", "فكة 15 جنيه (جديد)", "Fakka_15_NewUnite"),
    ("17", "فكة 15.5 جنيه", "Fakka_15.5_Unite"),
    ("18", "فكة 16.5 جنيه", "Fakka_16.5_Unite"),
    ("19", "فكة 17.5 جنيه", "Fakka_17.5_Unite"),
    ("20", "فكة 19.5 جنيه", "Fakka_19.5_NewUnite"),
    ("21", "فكة 20 جنيه", "Fakka_20_Unite"),
    ("22", "فكة 26 جنيه", "Fakka_26_Unite"),
    ("23", "📞 مارد 10 دقائق", "Mared_10_Minuts"),
    ("24", "🔄 مارد 10 فليكس", "Mared_10_Flexs"),
    ("25", "🌐 مارد 10 سوشيال", "Mared_10_Social"),
  ];

  /// 1. get_seamless - نفس دالة get_seamless() في البايثون:42 - حد أقصى 15 ثانية
  Future<({String seamless, String msisdn})> getSeamless() async {
    final url = Uri.parse(
        'http://mobile.vodafone.com.eg/checkSeamless/realms/vf-realm/protocol/openid-connect/auth?client_id=cash-app');
    final headers = {..._headers, 'If-Modified-Since': 'Thu, 02 Apr 2026 09:09:07 GMT'};
    final resp = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('فشل الاتصال - كود ${resp.statusCode}. تأكد من داتا فودافون أو VPN');
    final data = jsonDecode(resp.body);
    final raw = data['msisdn'] as String?;
    if (raw == null || raw.isEmpty) throw Exception('لم يتم العثور على رقم المحفظة (msisdn)');
    final msisdn = raw.startsWith('1') ? '0$raw' : raw;
    final seamless = data['seamlessToken'] as String?;
    if (seamless == null) throw Exception('لم يتم استلام seamlessToken');
    return (seamless: seamless, msisdn: msisdn);
  }

  /// 2. get_token
  Future<String> getToken(String seamless) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/auth/realms/vf-realm/protocol/openid-connect/token');
    final headers = {
      ..._headers,
      'Accept': 'application/json, text/plain, */*',
      'silentLogin': 'true',
      'CRP': 'false',
      'seamlessToken': seamless,
      'firstTimeLogin': 'true',
    };
    final body = {
      'grant_type': 'password',
      'client_secret': 'b86e30a8-ae29-467a-a71f-65c73f2ff5e3',
      'client_id': 'cash-app',
    };
    final resp = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) throw Exception('فشل التوكن - كود ${resp.statusCode}: ${resp.body.substring(0, 200)}');
    final data = jsonDecode(resp.body);
    final token = data['access_token'] as String?;
    if (token == null) throw Exception('لم يتم استلام access_token');
    return token;
  }

  /// 3. send_order - نفس دالة send_order() في البايثون:118
  Future<Map<String, dynamic>> sendOrder({
    required String productId,
    required String receiver,
    required String pin,
    required String msisdn,
    required String token,
  }) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/services/dxl/pom/productOrder');
    final payload = {
      "channel": {"name": "MobileApp"},
      "orderItem": [
        {
          "action": "insert",
          "id": productId,
          "product": {
            "characteristic": [
              {"name": "PaymentMethod", "value": "VFCash"},
              {"name": "USE_EMONEY", "value": "False"},
              {"name": "MerchantCode", "value": "81841829"}
            ],
            "id": productId,
            "relatedParty": [
              {"id": msisdn, "name": "MSISDN", "role": "Subscriber"},
              {"id": receiver, "name": "Receiver", "role": "Receiver"}
            ]
          },
          "@type": productId,
          "eCode": 0
        }
      ],
      "relatedParty": [
        {"id": pin, "name": "pin", "role": "Requestor"}
      ],
      "@type": "CashFakkaAndMared"
    };

    final headers = {
      ..._headers,
      'Accept': 'application/json',
      'api-host': 'ProductOrderingManagement',
      'useCase': 'CashFakkaAndMared',
      'api-version': 'v2',
      'msisdn': msisdn,
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json; charset=UTF-8',
    };

    final resp = await http.post(url, headers: headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 15));
    final data = resp.body.isNotEmpty ? jsonDecode(resp.body) as Map<String, dynamic> : <String, dynamic>{};
    data['_httpStatus'] = resp.statusCode;
    return data;
  }
}
