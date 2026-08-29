import 'dart:convert';
import 'package:http/http.dart' as http;

class FourteenService {
  Future<String?> login(String number, String password) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/auth/realms/vf-realm/protocol/openid-connect/token');
    final payload = {
      'grant_type': 'password',
      'username': number,
      'password': password,
      'client_secret': '95fd95fb-7489-4958-8ae6-d31a525cd20a',
      'client_id': 'ana-vodafone-app',
    };
    final headers = {
      'User-Agent': 'okhttp/4.12.0',
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip',
      'silentLogin': 'true',
      'x-agent-operatingsystem': '13',
      'clientId': 'AnaVodafoneAndroid',
      'Accept-Language': 'ar',
      'x-agent-device': 'Xiaomi 21061119AG',
      'x-agent-version': '2025.10.3',
      'x-agent-build': '1050',
      'digitalId': '28RI9U7ISU8SW',
      'device-id': '1df4efae59648ac3',
    };
    try {
      final r = await http.post(url, body: payload, headers: headers).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200) return (jsonDecode(r.body)['access_token'] as String?);
      return null;
    } catch (_) { return null; }
  }

  Future<({String? enc, String? tariffId, String? subId})> getEnc(String number, String token) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/services/dxl/epo/eligibleProductOffering');
    final params = {'parts.customerAccount.type': 'Consumer', 'customerAccountId': number, 'Accept-Language': 'ar', 'type': 'Tarrifs'};
    final headers = {
      'User-Agent': 'okhttp/4.12.0',
      'Accept': 'application/json',
      'api-host': 'EligibleProductOfferingHost',
      'useCase': 'Tarrifs',
      'Authorization': 'Bearer $token',
      'api-version': 'v2',
      'device-id': 'aba8140ecd392169',
      'x-agent-operatingsystem': '15',
      'clientId': 'AnaVodafoneAndroid',
      'x-agent-device': 'OPPO CPH2565',
      'x-agent-version': '2026.4.1',
      'x-agent-build': '1139',
      'msisdn': number,
      'Content-Type': 'application/json',
      'Accept-Language': 'ar',
    };
    try {
      final uri = url.replace(queryParameters: params);
      final r = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return (enc: null, tariffId: null, subId: null);
      final data = jsonDecode(r.body);
      String? tariffId;
      String? subId;
      try {
        tariffId = data[0]['id'][0]['value']?.toString();
        subId = data[0]['parts']['subscription']['id'][0]['value']?.toString();
      } catch (_) {}
      String? enc;
      for (final item in (data is List ? data : [])) {
        final offerings = item['parts']?['productOffering'] as List?;
        if (offerings == null) continue;
        for (final offer in offerings) {
          final ids = offer['id'] as List?;
          if (ids == null) continue;
          String? pid, eid;
          for (final i in ids) {
            if (i['schemeID'] == 'ProductID') pid = i['value']?.toString();
            if (i['schemeName'] == 'EncProductID') eid = i['value']?.toString();
          }
          if (pid == 'Worry_Free_14PT' && eid != null) enc = eid;
        }
      }
      return (enc: enc, tariffId: tariffId, subId: subId);
    } catch (_) { return (enc: null, tariffId: null, subId: null); }
  }

  Future<({bool success, String message, String? body})> convert(String number, String token, String enc, String tariffId, String subId) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/services/dxl/pom/productOrder');
    final payload = {
      'channel': {'name': 'MobileApp'},
      'characteristic': [{'name': 'MPTrackingID', 'value': subId}],
      'orderItem': [
        {
          'action': 'add',
          'id': 'Worry_Free_14PT',
          'itemPrice': [{'name': 'OriginalPrice', 'price': {'taxIncludedAmount': {'unit': 'LE', 'value': '0.0'}}}],
          'product': {
            'characteristic': [
              {'name': 'TariffRank', 'value': '6'},
              {'name': 'TariffID', 'value': '627'},
              {'name': 'Validity', '@type': 'MONTH', 'type': 'MONTH', 'value': '1'},
              {'name': 'MaxAdjustmentNumber', 'value': '1'},
              {'name': 'OfferRank', 'value': '1'},
              {'name': 'MigrationDesc', 'value': 'Intervention Offer Migration'},
              {'name': 'CohortId', 'value': '24'},
            ],
            'encProductId': enc,
            'productSpecification': [
              {'id': 'Retention With Offer', 'name': 'Category'},
              {'id': '0', 'name': 'RatePlanType'},
              {'id': 'Flex Family', 'name': 'BundleType'},
              {'id': 'Upon Renewal / Repurchase', 'name': 'MigrationRule'},
            ],
            'relatedParty': [
              {'id': number, 'name': 'MSISDN', 'referredType': 'prepaid', 'role': 'Subscriber', '@referredType': 'prepaid'},
              {'id': tariffId, 'name': 'TariffID', 'role': 'TariffID', '@referredType': 'prepaid'},
              {'id': number, 'name': 'MSISDN', 'role': 'Subscriber', '@referredType': 'prepaid'},
            ]
          },
          '@type': 'Access fees Discount',
        }
      ],
      '@type': 'Tariff',
    };
    final headers = {
      'User-Agent': 'okhttp/4.12.0',
      'Connection': 'Keep-Alive',
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip',
      'api-host': 'ProductOrderingManagement',
      'useCase': 'Tariff',
      'Authorization': 'Bearer $token',
      'api-version': 'v2',
      'device-id': 'aba8140ecd392169',
      'x-agent-operatingsystem': '15',
      'clientId': 'AnaVodafoneAndroid',
      'x-agent-device': 'OPPO CPH2565',
      'x-agent-version': '2026.4.1',
      'x-agent-build': '1139',
      'msisdn': number,
      'Accept-Language': 'ar',
      'Content-Type': 'application/json; charset=UTF-8',
    };
    try {
      final r = await http.post(url, headers: headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 10));
      if (r.statusCode == 200 || r.statusCode == 201) return (success: true, message: 'تم التحويل لنظام 14 قرش بنجاح', body: r.body);
      return (success: false, message: 'فشل التحويل: ${r.body.substring(0, r.body.length > 200 ? 200 : r.body.length)}', body: r.body);
    } catch (e) { return (success: false, message: 'خطأ: $e', body: null); }
  }
}
