import 'dart:convert';
import 'package:http/http.dart' as http;

class MarketApi {
  static const String _steamPriceBase =
      'https://europe-west1-skindex-97204.cloudfunctions.net/steamPrice';

  static const String _proxyImageBase =
      'https://europe-west1-skindex-97204.cloudfunctions.net/proxyImage';

  static const String _skinportPriceBase =
      'https://europe-west1-skindex-97204.cloudfunctions.net/skinportPrice';

  /// Bild-Proxy-URL
  static String proxyImageUrl(String originalUrl) {
    final encoded = Uri.encodeComponent(originalUrl);
    return '$_proxyImageBase?url=$encoded';
  }

  /// Steam-Listing-URL
  static String steamListingUrl(String marketHashName) {
    final encoded = Uri.encodeComponent(marketHashName);
    return 'https://steamcommunity.com/market/listings/730/$encoded';
  }

  /// Skinport-Listing-URL (sehr einfache Variante)
  static String skinportListingUrl(
    SkinportItem? item,
    String marketHashName, {
    String currency = 'EUR',
  }) {
    if (item != null) {
      if (item.itemPage != null && item.itemPage!.isNotEmpty) {
        return item.itemPage!;
      }
      if (item.marketPage != null && item.marketPage!.isNotEmpty) {
        return item.marketPage!;
      }
    }

    // Fallback: Skinport-Marktsuche
    final q = Uri.encodeQueryComponent(marketHashName);
    final cur = Uri.encodeQueryComponent(currency.toUpperCase());
    return 'https://skinport.com/market/730?search=$q&currency=$cur';
  }

  /// Steam-Preis über Cloud Function
  static Future<SteamPriceResult> fetchSteamPrice(
    String marketHashName, {
    int currency = 3,
    String country = 'DE',
  }) async {
    final uri = Uri.parse(_steamPriceBase).replace(queryParameters: {
      'market_hash_name': marketHashName,
      'currency': currency.toString(),
      'country': country,
    });

    final resp = await http.get(uri);

    if (resp.statusCode != 200) {
      return SteamPriceResult(
        success: false,
        error: 'HTTP ${resp.statusCode}: ${resp.body}',
      );
    }

    final data = json.decode(resp.body) as Map<String, dynamic>;
    final success = data['success'] == true;

    return SteamPriceResult(
      success: success,
      lowestPrice: data['lowest_price']?.toString(),
      medianPrice: data['median_price']?.toString(),
      volumeRaw: data['volume']?.toString(),
      error: success ? null : data['error']?.toString(),
    );
  }

  /// Skinport-Preis über Cloud Function
  static Future<SkinportItem> fetchSkinportPrice(
    String marketHashName, {
    String currency = 'EUR',
  }) async {
    final uri = Uri.parse(_skinportPriceBase).replace(queryParameters: {
      'market_hash_name': marketHashName,
      'currency': currency.toUpperCase(),
    });

    final resp = await http.get(uri);

    if (resp.statusCode == 404) {
      throw Exception('Item nicht auf Skinport gefunden');
    }
    if (resp.statusCode != 200) {
      throw Exception(
          'SkinportPrice HTTP ${resp.statusCode}: ${resp.body}');
    }

    final data = json.decode(resp.body);
    Map<String, dynamic>? obj;
    if (data is List && data.isNotEmpty) {
      obj = (data.first as Map).cast<String, dynamic>();
    } else if (data is Map) {
      obj = data.cast<String, dynamic>();
    }

    if (obj == null) {
      throw Exception('Unerwartetes Skinport-Antwortformat');
    }

    double? _parseNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '.'));
      return null;
    }

    return SkinportItem(
      marketHashName: obj['market_hash_name'] as String? ?? marketHashName,
      currency: obj['currency'] as String? ?? 'EUR',
      minPrice: _parseNum(obj['min_price']),
      maxPrice: _parseNum(obj['max_price']),
      suggestedPrice: _parseNum(obj['suggested_price']),
    );
  }
}

/// Ergebnis des Steam-Preis-Calls
class SteamPriceResult {
  final bool success;
  final String? lowestPrice;
  final String? medianPrice;
  final String? volumeRaw;
  final String? error; // <-- neu

  SteamPriceResult({
    required this.success,
    this.lowestPrice,
    this.medianPrice,
    this.volumeRaw,
    this.error,
  });

  factory SteamPriceResult.fromJson(Map<String, dynamic> json) {
    final success = json['success'] == true;
    return SteamPriceResult(
      success: success,
      lowestPrice: json['lowest_price'] as String?,
      medianPrice: json['median_price'] as String?,
      volumeRaw: json['volume'] as String?,
      error: success ? null : json['error'] as String?,
    );
  }
}

/// Ergebnis des Skinport-Preis-Calls
class SkinportItem {
  final String marketHashName;
  final double? minPrice;
  final double? maxPrice;
  final double? suggestedPrice;
  final String currency;

  // NEU:
  final String? itemPage;
  final String? marketPage;

  SkinportItem({
    required this.marketHashName,
    required this.currency,
    this.minPrice,
    this.maxPrice,
    this.suggestedPrice,
    this.itemPage,
    this.marketPage,
  });

  factory SkinportItem.fromJson(Map<String, dynamic> json) {
    double? parseNum(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v.replaceAll(',', '.'));
      return null;
    }

    return SkinportItem(
      marketHashName: json['market_hash_name'] as String? ?? '',
      currency: json['currency'] as String? ?? 'EUR',
      minPrice: parseNum(json['min_price']),
      maxPrice: parseNum(json['max_price']),
      suggestedPrice: parseNum(json['suggested_price']),
      itemPage: json['item_page'] as String?,     // <- neu
      marketPage: json['market_page'] as String?, // <- neu
    );
  }
}

