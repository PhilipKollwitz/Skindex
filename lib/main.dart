import 'dart:convert';
import 'services/market_api.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

/// Haupt-App
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Skindex',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: LoginScreen(
        nextScreenBuilder: (_) => const HomeScreen(),
      ),
    );
  }
}

/// Steam / Market Konfiguration
const int steamAppId = 730;
const String steamListingBase =
    'https://steamcommunity.com/market/listings/730/';

/// Firebase Cloud Functions (Proxy + Aggregator)
const String cloudFunctionsBase =
    'https://europe-west1-skindex-97204.cloudfunctions.net';
const String skinportPriceFunctionUrl = '$cloudFunctionsBase/skinportPrice';
const String proxyImageFunctionUrl = '$cloudFunctionsBase/proxyImage';
const String functionsBaseUrl =
    'https://europe-west1-skindex-97204.cloudfunctions.net';

/// Währungen (wie in deinem Python-Code)
const Map<String, int> currencyMap = {
  'EUR (€)': 3,
  'USD (\$)': 1,
  'GBP (£)': 2,
};

/// Item-Typen (entspricht ITEM_TYPES in Python)
class ItemType {
  final String key;
  final String label;
  final String assetPath;

  const ItemType({
    required this.key,
    required this.label,
    required this.assetPath,
  });
}

const Map<String, ItemType> itemTypes = {
  'skin': ItemType(
    key: 'skin',
    label: 'Waffenskin',
    assetPath: 'assets/data/skins.json',
  ),
  'crate': ItemType(
    key: 'crate',
    label: 'Kiste',
    assetPath: 'assets/data/crates.json',
  ),
  'sticker': ItemType(
    key: 'sticker',
    label: 'Sticker',
    assetPath: 'assets/data/stickers.json',
  ),
  'keychain': ItemType(
    key: 'keychain',
    label: 'Keychain/Charm',
    assetPath: 'assets/data/keychains.json',
  ),
  'patch': ItemType(
    key: 'patch',
    label: 'Patch',
    assetPath: 'assets/data/patches.json',
  ),
  'graffiti': ItemType(
    key: 'graffiti',
    label: 'Graffiti',
    assetPath: 'assets/data/graffiti.json',
  ),
  'agent': ItemType(
    key: 'agent',
    label: 'Agent',
    assetPath: 'assets/data/agents.json',
  ),
};

/// Datenmodell für ein Item (egal ob aus lokaler JSON oder aus Inventar)
class Item {
  final String id;
  final String name;
  final String? image;
  final String? marketHashName;
  final List<String> wears;
  final String typeKey;
  final int amount; // im Inventar evtl. > 1
  final String? rarityColor;  // Hex-Farbe aus Steam-Tags, z.B. "eb4b4b"
  final String? rarityName;   // Lokalisierter Rarityname, z.B. "Covert"

  Item({
    required this.id,
    required this.name,
    required this.typeKey,
    this.image,
    this.marketHashName,
    this.wears = const [],
    this.amount = 1,
    this.rarityColor,
    this.rarityName,
  });

  /// Für lokale JSON-Dateien (skins.json, crates.json, …)
  factory Item.fromJson(Map<String, dynamic> json, {required String typeKey}) {
    final dynamic wearsJson = json['wears'];
    List<String> wears = [];
    if (wearsJson is List) {
      wears = wearsJson
          .map((w) {
            if (w is Map) {
              return (w['name'] ?? '').toString();
            }
            return w.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList();
    }

    return Item(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      typeKey: typeKey,
      image: json['image']?.toString(),
      marketHashName: json['market_hash_name']?.toString(),
      wears: wears,
    );
  }

  /// Für Inventar-Items aus der Steam-API
  factory Item.fromInventoryJson(Map<String, dynamic> json) {
    return Item(
      id: (json['market_hash_name'] ?? json['name'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      typeKey: 'inventory',
      image: json['image']?.toString(),
      marketHashName: json['market_hash_name']?.toString(),
      amount: (json['amount'] is int)
          ? json['amount'] as int
          : int.tryParse(json['amount'].toString()) ?? 1,
      rarityColor: json['rarity_color']?.toString(),
      rarityName: json['rarity_name']?.toString(),
    );
  }
}

/// Skinport Preis-Resultat (wird aktuell nicht im UI genutzt,
/// kannst du bei Bedarf später verwenden)
class SkinportPriceResult {
  final String? currency;
  final double? minPrice;
  final double? maxPrice;
  final double? suggestedPrice;
  final String? error;

  SkinportPriceResult({
    this.currency,
    this.minPrice,
    this.maxPrice,
    this.suggestedPrice,
    this.error,
  });

  bool get success => error == null;
}

/// Repository zum Laden der lokalen JSON-Dateien
class ItemRepository {
  final Map<String, List<Item>> _cache = {};

  Future<List<Item>> getItemsForType(String typeKey) async {
    if (_cache.containsKey(typeKey)) {
      return _cache[typeKey]!;
    }
    final type = itemTypes[typeKey];
    if (type == null) {
      return [];
    }
    final jsonStr = await rootBundle.loadString(type.assetPath);
    final data = jsonDecode(jsonStr) as List<dynamic>;
    final items = data
        .map((e) => Item.fromJson(e as Map<String, dynamic>, typeKey: typeKey))
        .toList();
    _cache[typeKey] = items;
    return items;
  }
}

final itemRepository = ItemRepository();

/// Helper: Normalisierung + Score (wie in deinem Python score_match)
String _normalize(String s) => s.trim().toLowerCase();

List<int> _scoreMatch(String query, String name) {
  final q = _normalize(query);
  final n = _normalize(name);
  if (q.isEmpty) {
    return [9999, 9999, n.length];
  }
  final pos = n.indexOf(q);
  final starts = n.startsWith(q) ? 0 : 1;
  final contains = pos >= 0 ? pos : 9999;
  return [starts, contains, n.length];
}

/// Market-Hash-Name bauen (wie build_market_hash_name)
String buildMarketHashName(Item item, {String? wear}) {
  if (item.typeKey == 'skin' && wear != null && wear.isNotEmpty) {
    return '${item.name} ($wear)';
  }
  final mh = item.marketHashName;
  if (mh != null && mh.trim().isNotEmpty) {
    return mh;
  }
  return item.name;
}

/// Steam-Market-URL
String buildMarketUrl(String marketHashName) {
  final encoded = Uri.encodeComponent(marketHashName);
  return '$steamListingBase$encoded';
}

/// Proxy-URL für Bilder (Cloud Function)
String proxyImageUrl(String? rawUrl) {
  if (rawUrl == null || rawUrl.isEmpty) return '';
  final encoded = Uri.encodeComponent(rawUrl);
  return '$proxyImageFunctionUrl?url=$encoded';
}

/// Skinport-Preis über Firebase Function `skinportPrice`
Future<SkinportPriceResult> fetchSkinportPrice(
  String marketHashName, {
  String currency = 'EUR',
}) async {
  final uri = Uri.parse(skinportPriceFunctionUrl).replace(queryParameters: {
    'market_hash_name': marketHashName,
    'currency': currency,
  });

  final res =
      await http.get(uri).timeout(const Duration(seconds: 15));

  if (res.statusCode != 200) {
    return SkinportPriceResult(
      error: 'HTTP ${res.statusCode}: ${res.reasonPhrase}',
    );
  }

  final data = jsonDecode(res.body);
  Map<String, dynamic>? obj;

  if (data is List && data.isNotEmpty) {
    obj = (data.first as Map).cast<String, dynamic>();
  } else if (data is Map) {
    obj = data.cast<String, dynamic>();
  }

  if (obj == null) {
    return SkinportPriceResult(error: 'Unerwartetes Skinport-Antwortformat');
  }

  double? toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().replaceAll(',', '.');
    return double.tryParse(s);
  }

  return SkinportPriceResult(
    currency: obj['currency'] as String?,
    minPrice: toDouble(obj['min_price']),
    maxPrice: toDouble(obj['max_price']),
    suggestedPrice: toDouble(obj['suggested_price']),
  );
}

/// Inventory aus Steam holen (wie fetch_cs_inventory)
Future<List<Item>> fetchCsInventory(String steamId64,
    {int count = 2000}) async {
  final id = steamId64.trim();
  if (!RegExp(r'^\d+$').hasMatch(id)) {
    throw Exception('SteamID64 muss nur aus Ziffern bestehen (z.B. 7656119...).');
  }

  final items = <Map<String, dynamic>>[];
  String? lastAssetId;
  var more = true;

  while (more) {
    final params = <String, String>{
      'steamId': id,
      'count': count.toString(),
      if (lastAssetId != null) 'start_assetid': lastAssetId,
    };

    final uri = Uri.parse('$functionsBaseUrl/steamInventory')
        .replace(queryParameters: params);

    final res =
        await http.get(uri).timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception(
          'Inventar HTTP ${res.statusCode}: ${res.reasonPhrase}\nBody: ${res.body}');
    }

    final dynamic data = jsonDecode(res.body);
    if (data is! Map) {
      throw Exception('Ungültige Inventar-Antwort.');
    }

    final descriptions = (data['descriptions'] as List?) ?? [];
    final assets = (data['assets'] as List?) ?? [];

    if (descriptions.isEmpty) {
      throw Exception(
        'Inventar nicht lesbar. Ist es öffentlich? '
        '(Steam Profil -> Privacy -> Inventory: Public)',
      );
    }

    final descMap = <String, Map<String, dynamic>>{};
    for (final d in descriptions) {
      if (d is! Map) continue;
      final key = '${d['classid']}_${d['instanceid']}';
      descMap[key] = d.cast<String, dynamic>();
    }

    for (final a in assets) {
      if (a is! Map) continue;
      final key = '${a['classid']}_${a['instanceid']}';
      final d = descMap[key];
      if (d == null) continue;

      final icon = d['icon_url'] ?? d['icon_url_large'];
      String? imgUrl;
      if (icon != null) {
        imgUrl =
            'https://steamcommunity-a.akamaihd.net/economy/image/$icon/360fx360f';
      }

      final name = (d['name'] ?? '').toString();
      final marketHashName =
          (d['market_hash_name'] ?? d['market_name'] ?? name).toString();

      // Rarity aus Tags extrahieren
      String? rarityColor;
      String? rarityName;
      final tags = d['tags'];
      if (tags is List) {
        for (final t in tags) {
          if (t is Map && t['category'] == 'Rarity') {
            rarityColor = t['color']?.toString();
            rarityName = t['localized_tag_name']?.toString();
            break;
          }
        }
      }

      items.add({
        'name': name,
        'market_hash_name': marketHashName,
        'image': imgUrl,
        'amount': a['amount'] ?? 1,
        'rarity_color': rarityColor,
        'rarity_name': rarityName,
      });
    }

    more = (data['more_items'] == true);
    lastAssetId = data['last_assetid']?.toString();
  }

  // Duplikate mergen
  final merged = <String, Map<String, dynamic>>{};
  for (final it in items) {
    final key = (it['market_hash_name'] ?? it['name']).toString();
    if (merged.containsKey(key)) {
      final current = merged[key]!;
      final currentAmount =
          int.tryParse(current['amount'].toString()) ?? 1;
      final addAmount = int.tryParse(it['amount'].toString()) ?? 1;
      current['amount'] = currentAmount + addAmount;
    } else {
      merged[key] = Map<String, dynamic>.from(it);
    }
  }

  return merged.values.map((m) => Item.fromInventoryJson(m)).toList();
}

//
//  ---------- UI ----------
//

/// Startscreen: "Item suchen" / "Inventar anzeigen"
class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyNotifier = ValueNotifier<String>('EUR (€)');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skindex'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<String>(
          valueListenable: currencyNotifier,
          builder: (context, currency, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Was möchtest du machen?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItemCategoryScreen(
                          currencyNotifier: currencyNotifier,
                        ),
                      ),
                    );
                  },
                  child: const Text('Item suchen'),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InventoryIdScreen(
                          currencyNotifier: currencyNotifier,
                        ),
                      ),
                    );
                  },
                  child: const Text('Inventar anzeigen'),
                ),
                const Spacer(),
                const Text(
                  'Währung:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 4),
                DropdownButton<String>(
                  value: currency,
                  items: currencyMap.keys
                      .map(
                        (k) => DropdownMenuItem(
                          value: k,
                          child: Text(k),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) currencyNotifier.value = val;
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Kategorie-Auswahl (Skins, Kisten, Sticker, ...)
class ItemCategoryScreen extends StatelessWidget {
  final ValueNotifier<String> currencyNotifier;

  const ItemCategoryScreen({super.key, required this.currencyNotifier});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategorie auswählen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Item-Kategorie auswählen:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  ...itemTypes.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ItemSearchScreen(
                                typeKey: entry.key,
                                currencyNotifier: currencyNotifier,
                              ),
                            ),
                          );
                        },
                        child: Text(entry.value.label),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Suche mit Vorschlägen für eine Kategorie
class ItemSearchScreen extends StatefulWidget {
  final String typeKey;
  final ValueNotifier<String> currencyNotifier;

  const ItemSearchScreen({
    super.key,
    required this.typeKey,
    required this.currencyNotifier,
  });

  @override
  State<ItemSearchScreen> createState() => _ItemSearchScreenState();
}

class _ItemSearchScreenState extends State<ItemSearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  List<Item> _allItems = [];
  List<Item> _matches = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadItems();
    _queryController.addListener(_updateSuggestions);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    try {
      final items = await itemRepository.getItemsForType(widget.typeKey);
      setState(() {
        _allItems = items;
        _loading = false;
      });
      _updateSuggestions();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _updateSuggestions() {
    final q = _queryController.text.trim();
    List<Item> candidates = [];

    for (final it in _allItems) {
      final name = it.name;
      if (q.isEmpty) {
        candidates.add(it);
      } else {
        final n = _normalize(name);
        final tokens = _normalize(q)
            .split(RegExp(r'\s+'))
            .where((t) => t.isNotEmpty)
            .toList();
        if (tokens.every((t) => n.contains(t))) {
          candidates.add(it);
        }
      }
    }

    candidates.sort((a, b) {
      final sa = _scoreMatch(q, a.name);
      final sb = _scoreMatch(q, b.name);
      for (int i = 0; i < sa.length; i++) {
        final cmp = sa[i].compareTo(sb[i]);
        if (cmp != 0) return cmp;
      }
      return 0;
    });

    candidates = candidates.take(50).toList();

    setState(() {
      _matches = candidates;
    });
  }

  void _goNext(Item item) {
    if (widget.typeKey == 'skin' && item.wears.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WearSelectionScreen(
            item: item,
            currencyNotifier: widget.currencyNotifier,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItemDetailScreen(
            item: item,
            wear: null,
            currencyNotifier: widget.currencyNotifier,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = itemTypes[widget.typeKey]?.label ?? widget.typeKey;

    return Scaffold(
      appBar: AppBar(
        title: Text('Suche: $typeLabel'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text('Fehler: $_error'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _queryController,
                        decoration: const InputDecoration(
                          labelText: 'Name eingeben',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) {
                          if (_matches.isNotEmpty) {
                            _goNext(_matches.first);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Vorschläge:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _matches.isEmpty
                            ? const Center(child: Text('Keine Treffer.'))
                            : ListView.builder(
                                itemCount: _matches.length,
                                itemBuilder: (context, index) {
                                  final it = _matches[index];
                                  return ListTile(
                                    title: Text(it.name),
                                    onTap: () => _goNext(it),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

/// Wear-Auswahl für Skins
class WearSelectionScreen extends StatefulWidget {
  final Item item;
  final ValueNotifier<String> currencyNotifier;

  const WearSelectionScreen({
    super.key,
    required this.item,
    required this.currencyNotifier,
  });

  @override
  State<WearSelectionScreen> createState() => _WearSelectionScreenState();
}

class _WearSelectionScreenState extends State<WearSelectionScreen> {
  String? _selectedWear;

  @override
  void initState() {
    super.initState();
    if (widget.item.wears.isNotEmpty) {
      _selectedWear = widget.item.wears.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wears = widget.item.wears;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zustand auswählen'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: wears.isEmpty
            ? Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(
                          item: widget.item,
                          wear: null,
                          currencyNotifier: widget.currencyNotifier,
                        ),
                      ),
                    );
                  },
                  child: const Text('Weiter zu Details'),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.item.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Zustand (Wear):'),
                  const SizedBox(height: 8),
                  DropdownButton<String>(
                    value: _selectedWear,
                    items: wears
                        .map(
                          (w) =>
                              DropdownMenuItem(value: w, child: Text(w)),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedWear = val;
                      });
                    },
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _selectedWear == null
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ItemDetailScreen(
                                    item: widget.item,
                                    wear: _selectedWear,
                                    currencyNotifier:
                                        widget.currencyNotifier,
                                  ),
                                ),
                              );
                            },
                      child: const Text('Weiter'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Detail-Screen mit Bild + Steam-Preis + Skinport-Preis
class ItemDetailScreen extends StatefulWidget {
  final Item item;
  final String? wear;
  final ValueNotifier<String> currencyNotifier;

  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.wear,
    required this.currencyNotifier,
  });

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  // Skinport
  SkinportItem? _skinport;
  String? _skinportError;
  bool _loadingSkinport = false;

  String get _marketHashName =>
      buildMarketHashName(widget.item, wear: widget.wear);

  String get _steamListingUrl =>
      MarketApi.steamListingUrl(_marketHashName);

  String get _skinportListingUrl => MarketApi.skinportListingUrl(
        _skinport,
        _marketHashName,
        currency: _skinport?.currency ?? 'EUR',
      );

  // ---------- Steam ----------

  Future<void> _openSteamListing() async {
    final uri = Uri.parse(_steamListingUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konnte Steam-Listing nicht öffnen.')),
      );
    }
  }

  // ---------- Skinport ----------

  Future<void> _loadSkinportPrice() async {
    setState(() {
      _loadingSkinport = true;
      _skinportError = null;
    });

    try {
      final result = await MarketApi.fetchSkinportPrice(
        _marketHashName,
        currency: 'EUR',
      );
      setState(() {
        _skinport = result;
      });
    } catch (e) {
      setState(() {
        _skinportError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingSkinport = false);
      }
    }
  }

  Future<void> _openSkinportListing() async {
    final uri = Uri.parse(_skinportListingUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konnte Skinport-Listing nicht öffnen.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.wear == null
        ? widget.item.name
        : '${widget.item.name} (${widget.wear})';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Details'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _steamListingUrl,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: widget.item.image == null
                          ? const Text('Kein Bild in JSON vorhanden.')
                          : Image.network(
                              MarketApi.proxyImageUrl(widget.item.image!),
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, error, stack) {
                                return Text(
                                  'Bild konnte nicht geladen werden:\n$error',
                                  textAlign: TextAlign.center,
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 260,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton(
                          onPressed: _openSteamListing,
                          child: const Text(
                              'Steam Listing im Browser öffnen'),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Skinport Preis',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_loadingSkinport)
                                  const CircularProgressIndicator()
                                else if (_skinportError != null)
                                  Text(
                                    _skinportError!,
                                    style:
                                        const TextStyle(color: Colors.red),
                                  )
                                else if (_skinport != null)
                                  Text(
                                    'Min: ${_skinport!.minPrice ?? "-"} '
                                    '${_skinport!.currency}\n'
                                    'Max: ${_skinport!.maxPrice ?? "-"} '
                                    '${_skinport!.currency}\n'
                                    'Suggested: ${_skinport!.suggestedPrice ?? "-"} '
                                    '${_skinport!.currency}',
                                  )
                                else
                                  const Text('(noch nicht abgefragt)'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: _loadingSkinport
                              ? null
                              : _loadSkinportPrice,
                          child: _loadingSkinport
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Text('Skinport Preis anzeigen'),
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton(
                          onPressed: _openSkinportListing,
                          child: const Text(
                              'Skinport Listing im Browser öffnen'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Screen: SteamID64 eingeben und Inventar laden
class InventoryIdScreen extends StatefulWidget {
  final ValueNotifier<String> currencyNotifier;

  const InventoryIdScreen({super.key, required this.currencyNotifier});

  @override
  State<InventoryIdScreen> createState() => _InventoryIdScreenState();
}

class _InventoryIdScreenState extends State<InventoryIdScreen> {
  final TextEditingController _idController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _loadInventory() async {
    final id = _idController.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Bitte SteamID64 eingeben.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await fetchCsInventory(id);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InventoryListScreen(
            steamId: id,
            items: items,
            currencyNotifier: widget.currencyNotifier,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventar laden'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'SteamID64 eingeben (z.B. 7656119...):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '7656119...',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _loadInventory,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Inventar abrufen'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Liste des Inventars (mit Preis-Liveupdate + Gesamtwert)
class InventoryListScreen extends StatefulWidget {
  final String steamId;
  final List<Item> items;
  final ValueNotifier<String> currencyNotifier;

  const InventoryListScreen({
    super.key,
    required this.steamId,
    required this.items,
    required this.currencyNotifier,
  });

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  // Map: market_hash_name → Skinport-Preis
  final Map<String, SkinportPriceResult> _prices = {};
  bool _loadingAllPrices = false;
  int _processed = 0;
  double _totalValue = 0.0;

  /// Skinport-Währung aus der ausgewählten UI-Währung ableiten
  String _skinportCurrencyFromLabel(String label) {
    if (label.startsWith('USD')) return 'USD';
    if (label.startsWith('GBP')) return 'GBP';
    return 'EUR';
  }

  Future<void> _fetchAllPrices() async {
    if (_loadingAllPrices) return;

    setState(() {
      _loadingAllPrices = true;
      _processed = 0;
      _totalValue = 0;
    });

    // Gewählte Währung (EUR/USD/GBP)
    final uiCurrencyLabel = widget.currencyNotifier.value;
    final spCurrency = _skinportCurrencyFromLabel(uiCurrencyLabel);

    for (final item in widget.items) {
      final hash = buildMarketHashName(item);

      try {
        final result = await fetchSkinportPrice(
          hash,
          currency: spCurrency,
        );

        // Für den Wert nehmen wir preferiert suggestedPrice,
        // sonst minPrice, sonst maxPrice.
        final value =
            result.suggestedPrice ?? result.minPrice ?? result.maxPrice;

        if (!mounted) return;
        setState(() {
          _prices[hash] = result;
          _processed += 1;
          if (value != null) {
            _totalValue += value * item.amount;
          }
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _prices[hash] = SkinportPriceResult(error: e.toString());
          _processed += 1;
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _loadingAllPrices = false;
    });
  }

  String _labelForItem(Item item) {
    final hash = buildMarketHashName(item);
    final p = _prices[hash];

    if (p == null) return '(kein Skinport-Preis geladen)';
    if (!p.success) return 'Fehler: ${p.error}';

    final value = p.suggestedPrice ?? p.minPrice ?? p.maxPrice;
    if (value == null) return 'Kein Preis verfügbar';

    final curr = p.currency ?? 'EUR';
    return 'Skinport: ${value.toStringAsFixed(2)} $curr';
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    return Scaffold(
      appBar: AppBar(
        title: Text('Inventar von ${widget.steamId}'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _loadingAllPrices ? null : _fetchAllPrices,
                    child: _loadingAllPrices
                        ? const Text('Preise werden geladen ...')
                        : const Text(
                            'Gesamtwert anzeigen (Skinport-Preise laden)',
                          ),
                  ),
                ),
              ],
            ),
          ),
          if (_processed > 0 || _loadingAllPrices)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Fortschritt: $_processed / ${items.length} Items\n'
                  'Bisheriger Gesamtwert (Skinport, geschätzt): '
                  '${_totalValue.toStringAsFixed(2)} ${widget.currencyNotifier.value.split(" ").first}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, index) {
                final it = items[index];
                final hash = buildMarketHashName(it);
                final proxied = proxyImageUrl(it.image ?? '');
                return ListTile(
                  leading: it.image != null && it.image!.isNotEmpty
                      ? Image.network(
                          proxied,
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                          errorBuilder: (c, e, s) =>
                              const Icon(Icons.image_not_supported),
                        )
                      : const Icon(Icons.inventory_2_outlined),
                  title: Text(it.name),
                  subtitle: Text(
                    'Anzahl: ${it.amount}\n${_labelForItem(it)}',
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(
                          item: it,
                          wear: null,
                          currencyNotifier: widget.currencyNotifier,
                        ),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.open_in_new),
                    onPressed: () async {
                      final url = buildMarketUrl(hash); // optional: Steam-Link
                      final uri = Uri.parse(url);
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

