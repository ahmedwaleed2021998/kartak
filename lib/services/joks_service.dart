import 'dart:convert';
import 'package:http/http.dart' as http;

class JoksService {
  static const _deviceHeaders = {
    'User-Agent': 'okhttp/4.12.0',
    'x-agent-operatingsystem': '15',
    'clientId': 'AnaVodafoneAndroid',
    'Accept-Language': 'ar',
    'x-agent-device': 'Samsung SM-A165F',
    'x-agent-version': '2025.12.2',
    'x-agent-build': '1080',
    'digitalId': '25VT5Q5QWG8DK',
    'device-id': 'b26ba335813fad21',
  };

  Future<({bool success, String? token, String message})> loginVodafone(String phone, String password) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/auth/realms/vf-realm/protocol/openid-connect/token');
    final payload = {
      'grant_type': 'password',
      'username': phone,
      'password': password,
      'client_secret': '95fd95fb-7489-4958-8ae6-d31a525cd20a',
      'client_id': 'ana-vodafone-app',
    };
    final headers = {
      'User-Agent': 'okhttp/4.12.0',
      'Accept': 'application/json, text/plain, */*',
      'Accept-Encoding': 'gzip',
      'Content-Type': 'application/x-www-form-urlencoded',
      'silentLogin': 'true',
      ..._deviceHeaders,
    };
    try {
      final resp = await http.post(url, body: payload, headers: headers).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final token = data['access_token'] as String?;
        if (token != null && token.isNotEmpty) return (success: true, token: token, message: 'تم تسجيل الدخول بنجاح');
        return (success: false, token: null, message: 'لم يتم العثور على التوكن');
      }
      return (success: false, token: null, message: 'فشل تسجيل الدخول (كود ${resp.statusCode})');
    } catch (e) {
      if (e.toString().contains('SocketException') || e.toString().contains('Connection')) {
        return (success: false, token: null, message: 'خطأ في الاتصال بالإنترنت');
      }
      return (success: false, token: null, message: 'حدث خطأ: $e');
    }
  }

  Future<List<dynamic>> getDiscountOffers(String token, String phone) async {
    final url = Uri.parse('https://mobile.vodafone.com.eg/services/dxl/epo/eligibleProductOffering');
    final params = {
      'customerAccountId': phone,
      'parts.customerAccount.type': 'Consumer',
      'Accept-Language': 'ar',
      'type': 'Tarrifs',
    };
    final headers = {
      'User-Agent': 'okhttp/4.12.0',
      'Connection': 'Keep-Alive',
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip',
      'api-host': 'EligibleProductOfferingHost',
      'useCase': 'Tarrifs',
      'Authorization': 'Bearer $token',
      'api-version': 'v2',
      'device-id': 'b26ba335813fad21',
      'x-agent-operatingsystem': '15',
      'clientId': 'AnaVodafoneAndroid',
      'x-agent-device': 'Samsung SM-A165F',
      'x-agent-version': '2025.12.2',
      'x-agent-build': '1080',
      'msisdn': phone,
      'Content-Type': 'application/json',
      'Accept-Language': 'ar',
    };
    try {
      final uri = url.replace(queryParameters: params);
      final resp = await http.get(uri, headers: headers).timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is List) return data;
        return [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Map<String, dynamic>? extractPriceFromDesc(String description) {
    try {
      final patterns = [
        RegExp(r'جدد ب(\d+) بدل (\d+)'),
        RegExp(r'ب(\d+) بدل (\d+)'),
        RegExp(r'بسعر (\d+) بدل (\d+)'),
        RegExp(r'و جدد ب(\d+) بدل (\d+)'),
        RegExp(r'خصم (\d+) بدل (\d+)'),
        RegExp(r'ب(\d+) بدل (\d+) جنيه'),
        RegExp(r'جدد ب(\d+) بدل (\d+) جنيه'),
      ];
      for (final p in patterns) {
        final m = p.firstMatch(description);
        if (m != null) {
          final discounted = int.parse(m.group(1)!);
          final original = int.parse(m.group(2)!);
          final discountAmount = original - discounted;
          final discountPct = original > 0 ? ((original - discounted) / original) * 100 : 0;
          return {
            'original': original,
            'discounted': discounted,
            'discount_percentage': discountPct,
            'discount_amount': discountAmount,
          };
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  String extractBundleName(String name, String description) {
    final patterns = [RegExp(r'فليكس (\d+)'), RegExp(r'باقة (\d+)'), RegExp(r'على (\d+)'), RegExp(r'في (\d+)'), RegExp(r'فليكس(\d+)')];
    for (final p in patterns) {
      final m = p.firstMatch(description);
      if (m != null) return 'فليكس ${m.group(1)}';
    }
    if (name.trim().isNotEmpty) return name;
    if (description.contains('فليكس')) return 'فليكس';
    return 'الباقة الحالية';
  }

  Map<String, String> extractOfferDetails(Map lineItem) {
    final details = {'tariff_id': '', 'product_id': '', 'tariff_rank': '1', 'offer_rank': '1', 'cohort_id': '30'};
    final characteristics = lineItem['characteristic'];
    if (characteristics is Map) {
      final values = characteristics['characteristicsValue'];
      if (values is List) {
        for (final char in values) {
          if (char is Map) {
            if (char['characteristicName'] == 'TariffID') details['tariff_id'] = char['value']?.toString() ?? '';
            if (char['characteristicName'] == 'TibcoID') details['product_id'] = char['value']?.toString() ?? '';
            if (char['characteristicName'] == 'OfferRank') details['offer_rank'] = char['value']?.toString() ?? '1';
            if (char['characteristicName'] == 'CohortId') details['cohort_id'] = char['value']?.toString() ?? '30';
          }
        }
      }
    }
    if (details['product_id']!.isEmpty) {
      final idList = lineItem['id'];
      if (idList is List) {
        for (final idItem in idList) {
          if (idItem is Map && idItem['schemeName'] == 'ProductID') {
            details['product_id'] = idItem['value']?.toString() ?? '';
            break;
          }
        }
      }
    }
    final categories = lineItem['category'];
    if (categories is List) {
      for (final cat in categories) {
        if (cat is Map && cat['listHierarchyId'] == 'TariffRank') {
          details['tariff_rank'] = cat['value']?.toString() ?? '1';
          break;
        }
      }
    }
    return details.map((k, v) => MapEntry(k, v.toString()));
  }

  List<Map<String, dynamic>> extractAllDiscountOffers(List offersData) {
    final all = <Map<String, dynamic>>[];
    for (final offerGroup in offersData) {
      if (offerGroup is! Map) continue;
      final parts = offerGroup['parts'];
      if (parts is! Map) continue;
      final productOfferings = parts['productOffering'];
      if (productOfferings is! List) continue;
      for (final product in productOfferings) {
        if (product is! Map) continue;
        final lineItems = product['lineItem'];
        if (lineItems is! List) continue;
        for (final lineItem in lineItems) {
          if (lineItem is! Map) continue;
          final offerType = lineItem['type']?.toString() ?? '';
          final description = lineItem['desc']?.toString() ?? '';
          final name = lineItem['name']?.toString() ?? '';
          final isDiscount = (offerType == 'Access fees Discount' || offerType == 'Usage fees Discount') &&
              ['جدد', 'خصم', 'بدل', 'خليك', 'بسعر', 'بدلاً'].any((k) => description.contains(k));
          if (!isDiscount) continue;
          final priceInfo = extractPriceFromDesc(description);
          if (priceInfo == null) continue;
          final bundleName = extractBundleName(name, description);
          final details = extractOfferDetails(lineItem);
          if (details['product_id']!.isEmpty || details['tariff_id']!.isEmpty) continue;
          final offer = {
            'name': name,
            'bundle_name': bundleName,
            'desc': description,
            'original_price': priceInfo['original'],
            'discounted_price': priceInfo['discounted'],
            'discount_amount': priceInfo['discount_amount'],
            'discount_percentage': priceInfo['discount_percentage'],
            'type': offerType,
            'tariff_id': details['tariff_id'],
            'product_id': details['product_id'],
            'tariff_rank': details['tariff_rank'],
            'offer_rank': details['offer_rank'],
            'cohort_id': details['cohort_id'],
            'is_half_price': (priceInfo['discount_percentage'] as double) >= 45,
          };
          all.add(offer);
        }
      }
    }
    if (all.isNotEmpty) {
      final half = all.where((o) => o['is_half_price'] == true).toList()..sort((a, b) => (b['discount_percentage'] as double).compareTo(a['discount_percentage'] as double));
      final other = all.where((o) => o['is_half_price'] != true).toList()..sort((a, b) => (b['discount_percentage'] as double).compareTo(a['discount_percentage'] as double));
      return [...half, ...other];
    }
    return all;
  }

  Future<({bool success, String message})> purchaseDiscountOffer(String token, String phone, Map<String, dynamic> offer) async {
    if (offer['product_id'] == null || offer['tariff_id'] == null) return (success: false, message: 'بيانات العرض غير مكتملة');
    final url = Uri.parse('https://mobile.vodafone.com.eg/services/dxl/pom/productOrder');
    final payload = {
      'channel': {'name': 'MobileApp'},
      'orderItem': [
        {
          'action': 'add',
          'id': offer['product_id'],
          'itemPrice': [
            {
              'name': 'OriginalPrice',
              'price': {'taxIncludedAmount': {'unit': 'LE', 'value': offer['discounted_price'].toString()}}
            },
            {
              'name': 'MigrationFees',
              'price': {'taxIncludedAmount': {'unit': 'LE', 'value': '0.0'}}
            }
          ],
          'product': {
            'characteristic': [
              {'name': 'TariffRank', 'value': offer['tariff_rank'] ?? '1'},
              {'name': 'TariffID', 'value': offer['tariff_id']},
              {'name': 'Quota', 'value': ''},
              {'name': 'Validity', '@type': 'MONTH', 'value': '1'},
              {'name': 'MaxAdjustmentNumber', 'value': '1'},
              {'name': 'offerRank', 'value': offer['offer_rank'] ?? '1'},
              {'name': 'MigrationDesc', 'value': 'Intervention Offer Migration'},
              {'name': 'CohortId', 'value': offer['cohort_id'] ?? '30'},
            ],
            'productSpecification': [
              {'id': 'Retention With Offer', 'name': 'Category'},
              {'id': 'Upon Renewal / Repurchase', 'name': 'MigrationRule'},
              {'id': '0', 'name': 'RatePlanType'},
              {'id': 'Flex Family', 'name': 'BundleType'},
            ],
            'relatedParty': [
              {'id': phone, 'name': 'MSISDN', '@referredType': 'prepaid', 'role': 'Subscriber'},
              {'id': offer['tariff_id'], 'name': 'TariffID', '@referredType': 'prepaid', 'role': 'TariffID'},
            ]
          },
          '@type': offer['type'] ?? 'Access fees Discount',
        }
      ],
      '@type': 'InterventionTariff',
    };
    final headers = {
      'User-Agent': 'okhttp/4.12.0',
      'Connection': 'Keep-Alive',
      'Accept': 'application/json',
      'Accept-Encoding': 'gzip',
      'Content-Type': 'application/json; charset=UTF-8',
      'api-host': 'ProductOrderingManagement',
      'useCase': 'InterventionTariff',
      'Authorization': 'Bearer $token',
      'api-version': 'v2',
      'device-id': 'b26ba335813fad21',
      'x-agent-operatingsystem': '15',
      'clientId': 'AnaVodafoneAndroid',
      'x-agent-device': 'Samsung SM-A165F',
      'x-agent-version': '2025.12.2',
      'x-agent-build': '1080',
      'msisdn': phone,
      'Accept-Language': 'ar',
    };
    try {
      final resp = await http.post(url, headers: headers, body: jsonEncode(payload)).timeout(const Duration(seconds: 12));
      Map<String, dynamic> data = {};
      try { data = jsonDecode(resp.body) as Map<String, dynamic>; } catch (_) {}
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        if (data['code'] == '1008') return (success: true, message: 'تم الاشتراك في خصم ${offer['discount_amount']} جنيه على ${offer['bundle_name']}');
        if (data['state'] == 'completed') return (success: true, message: 'تم تفعيل خصم ${offer['discount_amount']} جنيه على ${offer['bundle_name']}');
        return (success: true, message: 'تم إرسال طلب خصم ${offer['discount_amount']} جنيه على ${offer['bundle_name']}');
      }
      if (resp.statusCode == 400 && data['code'] == '1008') return (success: true, message: 'تم الاشتراك في خصم ${offer['discount_amount']} جنيه على ${offer['bundle_name']}');
      final code = data['code']?.toString() ?? '';
      final reason = data['reason']?.toString() ?? resp.body.substring(0, resp.body.length > 100 ? 100 : resp.body.length);
      if (code == '1001') return (success: false, message: 'تمت معالجة الطلب مسبقاً');
      if (code == '1002') return (success: false, message: 'العرض غير متاح حالياً');
      return (success: false, message: 'فشل التفعيل: $reason');
    } catch (e) {
      if (e.toString().contains('Timeout')) return (success: false, message: 'انتهت مهلة الاتصال');
      return (success: false, message: 'حدث خطأ: $e');
    }
  }
}
