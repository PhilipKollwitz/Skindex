import 'dart:convert';
import 'package:http/http.dart' as http;

class MarketApi {
  static const String _proxyImageBase =
      'https://europe-west1-skindex-97204.cloudfunctions.net/proxyImage';

  static const String _skinportPriceBase =
      'https://europe-west1-skindex-97204.cloudfunctions.net/skinportPrice';

  static const String _skinportMarketBase =
      'https://europe-west1-skindex-97204.cloudfunctions.net/skinportMarket';

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

  /// Markt-Daten (Deals + Trending) über Cloud Function
  static Future<MarketData> fetchMarketData({String currency = 'EUR'}) async {
    final uri = Uri.parse(_skinportMarketBase).replace(
      queryParameters: {'currency': currency.toUpperCase()},
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('skinportMarket HTTP ${resp.statusCode}');
    }
    final data = json.decode(resp.body) as Map<String, dynamic>;
    return MarketData(
      deals: (data['deals'] as List)
          .map((j) => MarketDeal.fromJson(j as Map<String, dynamic>))
          .toList(),
      trending: (data['trending'] as List)
          .map((j) => MarketTrend.fromJson(j as Map<String, dynamic>))
          .toList(),
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

// ─────────────────────────────────────────────────────────────────────────────
// Market Data Models
// ─────────────────────────────────────────────────────────────────────────────

class MarketDeal {
  final String marketHashName;
  final double minPrice;
  final double suggestedPrice;
  final int discountPct;
  final int quantity;
  final String? iconUrl;
  final String? itemPage;
  final int? updatedAt;

  const MarketDeal({
    required this.marketHashName,
    required this.minPrice,
    required this.suggestedPrice,
    required this.discountPct,
    required this.quantity,
    this.iconUrl,
    this.itemPage,
    this.updatedAt,
  });

  factory MarketDeal.fromJson(Map<String, dynamic> j) => MarketDeal(
        marketHashName: j['market_hash_name'] as String,
        minPrice: (j['min_price'] as num).toDouble(),
        suggestedPrice: (j['suggested_price'] as num).toDouble(),
        discountPct: (j['discount_pct'] as num).toInt(),
        quantity: (j['quantity'] as num).toInt(),
        iconUrl: j['icon_url'] as String?,
        itemPage: j['item_page'] as String?,
        updatedAt: j['updated_at'] != null ? (j['updated_at'] as num).toInt() : null,
      );
}

class MarketTrend {
  final String marketHashName;
  final double suggestedPrice;
  final double? minPrice;
  final int discountPct;
  final int quantity;
  final String? iconUrl;

  const MarketTrend({
    required this.marketHashName,
    required this.suggestedPrice,
    required this.discountPct,
    required this.quantity,
    this.minPrice,
    this.iconUrl,
  });

  factory MarketTrend.fromJson(Map<String, dynamic> j) => MarketTrend(
        marketHashName: j['market_hash_name'] as String,
        suggestedPrice: (j['suggested_price'] as num).toDouble(),
        minPrice: j['min_price'] != null ? (j['min_price'] as num).toDouble() : null,
        discountPct: (j['discount_pct'] as num? ?? 0).toInt(),
        quantity: (j['quantity'] as num).toInt(),
        iconUrl: j['icon_url'] as String?,
      );
}

class MarketData {
  final List<MarketDeal> deals;
  final List<MarketTrend> trending;
  const MarketData({required this.deals, required this.trending});
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

