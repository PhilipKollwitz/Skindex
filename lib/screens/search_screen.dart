import 'package:flutter/material.dart';
import '../main.dart' as app;
import '../main.dart' show fetchBulkSkinportPrices, SkinportPriceResult, currencySymbol;
import 'item_detail_screen.dart';

const Color _cardBg = Color(0xFF0C1A0C);
const Color _green = Color(0xFF4ADE80);
const Color _cardBorder = Color(0xFF1A3520);
const Color _textDim = Color(0xFF6B8A6B);
const Color _searchBg = Color(0xFF0F1F0F);

// ─────────────────────────────────────────
// SearchScreen — embedded as a tab (no Scaffold)
// ─────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  final String currency;
  const SearchScreen({super.key, this.currency = 'EUR'});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _searchCtrl = TextEditingController();
  String _query = '';

  // Items sorted by price, and their pre-loaded prices
  final Map<int, List<app.Item>> _items = {};
  final Map<int, Map<String, SkinportPriceResult>> _prices = {};
  final Map<int, bool> _loading = {};

  static const _tabLabels = [
    'WAFFENSKINS',
    'KISTEN',
    'HANDSCHUHE',
    'STICKER',
    'GRAFFITI',
    'KEYCHAINS',
    'PATCHES',
    'AGENTS',
  ];

  static const _tabTypeKeys = [
    'skin',
    'crate',
    'gloves',
    'sticker',
    'graffiti',
    'keychain',
    'patch',
    'agent',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabLabels.length, vsync: this);
    _loadTab(0);
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) _loadTab(_tabs.index);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _isGlove(String name) {
    final n = name.toLowerCase();
    return n.contains('gloves') || n.contains('hand wraps') || n.contains('wraps');
  }

  // Build the representative market hash name for price lookup
  String _mhn(app.Item item) {
    if (item.typeKey == 'skin' && item.wears.isNotEmpty) {
      // Prefer Factory New, otherwise first wear
      final wear = item.wears.contains('Factory New')
          ? 'Factory New'
          : item.wears.first;
      return '${item.name} ($wear)';
    }
    return item.marketHashName ?? item.name;
  }

  Future<void> _loadTab(int i) async {
    if (_items.containsKey(i) || (_loading[i] ?? false)) return;
    setState(() => _loading[i] = true);

    List<app.Item> result = [];
    try {
      final typeKey = _tabTypeKeys[i];
      if (typeKey == 'gloves') {
        final all = await app.itemRepository.getItemsForType('skin');
        result = all.where((x) => _isGlove(x.name)).toList();
      } else if (typeKey == 'skin') {
        final all = await app.itemRepository.getItemsForType('skin');
        result = all.where((x) => !_isGlove(x.name)).toList();
      } else {
        result = await app.itemRepository.getItemsForType(typeKey);
      }

      // Bulk-fetch prices and sort by price descending
      final hashes = result.map(_mhn).toList();
      final priceMap = await fetchBulkSkinportPrices(hashes, currency: widget.currency);

      // Sort: items with prices first (by price desc), then unprice items
      result.sort((a, b) {
        final pa = priceMap[_mhn(a)]?.suggestedPrice ?? -1;
        final pb = priceMap[_mhn(b)]?.suggestedPrice ?? -1;
        return pb.compareTo(pa);
      });

      if (mounted) {
        setState(() {
          _items[i] = result;
          _prices[i] = priceMap;
          _loading[i] = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _items[i] = result;
          _loading[i] = false;
        });
      }
    }
  }

  List<app.Item> _filteredForTab(int i) {
    final all = _items[i] ?? [];
    if (_query.isEmpty) return all.take(60).toList();
    final q = _query.toLowerCase();
    return all.where((x) => x.name.toLowerCase().contains(q)).take(100).toList();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    return Column(
      children: [
        SizedBox(height: topPad + 12),

        // ── App bar row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.search_rounded, color: _green, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Markt-Explorer',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Category tabs
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: _green,
          indicatorWeight: 2.5,
          labelColor: _green,
          unselectedLabelColor: _textDim,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
          dividerColor: _cardBorder,
          tabs: _tabLabels.map((l) => Tab(text: l)).toList(),
        ),

        const SizedBox(height: 14),

        // ── Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: _searchBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _cardBorder, width: 1),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.search_rounded, color: _textDim, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Suche nach Skins, Wear oder Mustern.',
                      hintStyle: TextStyle(color: _textDim, fontSize: 14),
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
                if (_query.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.close_rounded, color: _textDim, size: 18),
                    ),
                  ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // ── Grid
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: List.generate(_tabLabels.length, (i) => _TabGrid(
              items: _filteredForTab(i),
              prices: _prices[i] ?? {},
              currency: widget.currency,
              loading: _loading[i] ?? (_items[i] == null),
            )),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Grid for one tab
// ─────────────────────────────────────────
class _TabGrid extends StatelessWidget {
  final List<app.Item> items;
  final Map<String, SkinportPriceResult> prices;
  final String currency;
  final bool loading;

  const _TabGrid({
    required this.items,
    required this.prices,
    required this.currency,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: _green, strokeWidth: 2),
      );
    }
    if (items.isEmpty) {
      return const Center(
        child: Text('Keine Items gefunden.', style: TextStyle(color: _textDim)),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.72,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, i) => _ItemCard(
        item: items[i],
        prices: prices,
        currency: currency,
      ),
    );
  }
}

// ─────────────────────────────────────────
// Item card
// ─────────────────────────────────────────
class _ItemCard extends StatelessWidget {
  final app.Item item;
  final Map<String, SkinportPriceResult> prices;
  final String currency;

  const _ItemCard({
    required this.item,
    required this.prices,
    required this.currency,
  });

  String get _mhn {
    if (item.typeKey == 'skin' && item.wears.isNotEmpty) {
      final wear = item.wears.contains('Factory New')
          ? 'Factory New'
          : item.wears.first;
      return '${item.name} ($wear)';
    }
    return item.marketHashName ?? item.name;
  }

  @override
  Widget build(BuildContext context) {
    final parts = item.name.split(' | ');
    final weaponType = parts.length > 1 ? parts[0] : '';
    final skinName = parts.length > 1 ? parts[1] : item.name;

    final isStatTrak = item.name.startsWith('StatTrak™');
    final isSouvenir = item.name.startsWith('Souvenir');

    final imgUrl = item.image != null ? app.proxyImageUrl(item.image) : null;
    final price = prices[_mhn]?.suggestedPrice;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ItemDetailScreen(item: item)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _cardBorder, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                    child: imgUrl != null
                        ? Image.network(
                            imgUrl,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _ImgPlaceholder(),
                          )
                        : _ImgPlaceholder(),
                  ),
                  if (isStatTrak || isSouvenir)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: _Badge(
                        label: isStatTrak ? 'STATTRAK™' : 'SOUVENIR',
                        color: isStatTrak
                            ? const Color(0xFFFF6B35)
                            : _green,
                      ),
                    ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (weaponType.isNotEmpty)
                    Text(
                      weaponType.toUpperCase(),
                      style: const TextStyle(
                        color: _textDim,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    skinName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Price (pre-loaded)
                  const Text(
                    'SKINPORT',
                    style: TextStyle(
                      color: _textDim,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    price != null
                        ? '${currencySymbol(currency)}${price.toStringAsFixed(2)}'
                        : '—',
                    style: TextStyle(
                      color: price != null ? _green : _textDim,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
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

// ─────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────
class _ImgPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: const Color(0xFF0F1F10),
      child: const Center(
        child: Icon(Icons.image_not_supported_outlined, color: _textDim, size: 28),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
