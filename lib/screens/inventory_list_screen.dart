import 'package:flutter/material.dart';
import '../main.dart' show Item, fetchBulkSkinportPrices, SkinportPriceResult, buildMarketHashName, proxyImageUrl;
import '../services/portfolio_storage.dart';
import 'portfolio_screen.dart';

// ── Theme colors
const Color _bg = Color(0xFF060E06);
const Color _cardBg = Color(0xFF0C1A0C);
const Color _green = Color(0xFF4ADE80);
const Color _cardBorder = Color(0xFF1A3520);
const Color _textDim = Color(0xFF6B8A6B);
const Color _valueBg = Color(0xFF081A0A);

// ─────────────────────────────────────────
// Inventory List Screen
// ─────────────────────────────────────────
class InventoryListScreen extends StatefulWidget {
  final String steamId;
  final List<Item> items;
  final VoidCallback onBack;

  const InventoryListScreen({
    super.key,
    required this.steamId,
    required this.items,
    required this.onBack,
  });

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final Map<String, SkinportPriceResult> _prices = {};
  bool _loadingPrices = true;
  double _totalValue = 0;
  double _initialTotal = 0;
  bool _initialSet = false;
  Map<String, double> _initialPrices = {};
  String _searchQuery = '';
  bool _showSearch = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPrices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPrices() async {
    setState(() => _loadingPrices = true);

    // Bereits gespeicherte Initial-Preise laden (Firestore kann durch Ad-Blocker blockiert sein)
    try {
      final savedInitial =
          await PortfolioStorage.loadInitialPrices(widget.steamId);
      if (savedInitial != null && mounted) {
        setState(() {
          _initialPrices = savedInitial;
          _initialTotal = savedInitial.values.fold(0, (s, v) => s + v);
          _initialSet = true;
        });
      }
    } catch (_) {}

    final hashes = widget.items.map(buildMarketHashName).toList();
    final bulk = await fetchBulkSkinportPrices(hashes);
    if (!mounted) return;

    // UI sofort freigeben — Items ohne Skinport-Preis zeigen "—"
    setState(() {
      _prices.addAll(bulk);
      _totalValue = _calcTotal();
      _loadingPrices = false;
    });

    // Firestore im Hintergrund — blockiert UI nicht
    _persistToFirestore();
  }

  Future<void> _persistToFirestore() async {
    try {
      final total = _totalValue;
      final currentPriceMap = <String, double>{};
      for (final item in widget.items) {
        final hash = buildMarketHashName(item);
        final price = _prices[hash]?.suggestedPrice;
        if (price != null) currentPriceMap[hash] = price;
      }

      await PortfolioStorage.saveSteamProfile(widget.steamId, widget.items);
      await PortfolioStorage.saveInitialIfAbsent(widget.steamId, currentPriceMap);
      await PortfolioStorage.appendValueHistory(widget.steamId, total);

      final init = await PortfolioStorage.loadInitialPrices(widget.steamId);
      if (!mounted || init == null) return;
      setState(() {
        _initialPrices = init;
        _initialTotal = init.values.fold(0, (s, v) => s + v);
        _initialSet = true;
      });
    } catch (_) {}
  }

  double _calcTotal() {
    double sum = 0;
    for (final item in widget.items) {
      final hash = buildMarketHashName(item);
      final price = _prices[hash]?.suggestedPrice;
      if (price != null) sum += price * item.amount;
    }
    return sum;
  }

  double get _changePercent {
    if (_initialTotal <= 0) return 0;
    return ((_totalValue - _initialTotal) / _initialTotal) * 100;
  }

  List<Item> get _filteredItems {
    if (_searchQuery.isEmpty) return widget.items;
    final q = _searchQuery.toLowerCase();
    return widget.items.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final changePercent = _changePercent;
    final isPositive = changePercent >= 0;
    final filtered = _filteredItems;

    return Container(
      color: _bg,
      child: Column(
        children: [
          SizedBox(height: topPad),

          // ── Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                // Reset-Button
                _IconBtn(
                  icon: Icons.arrow_back_rounded,
                  onTap: widget.onBack,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Inventar',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${widget.items.length} ITEMS ERKANNT',
                        style: const TextStyle(
                          color: _green,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                _IconBtn(
                  icon: Icons.tune_rounded,
                  onTap: () {}, // Filter – folgt
                ),
                const SizedBox(width: 8),
                _IconBtn(
                  icon: Icons.search_rounded,
                  onTap: () => setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  }),
                ),
              ],
            ),
          ),

          // ── Search bar (eingeklappt)
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _cardBorder),
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Item suchen...',
                    hintStyle: TextStyle(color: _textDim),
                    prefixIcon: Icon(Icons.search_rounded, color: _textDim, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
            ),

          const SizedBox(height: 12),

          // ── Value Card (tippbar → Portfolio Screen)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GestureDetector(
              onTap: _totalValue > 0
                  ? () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PortfolioScreen(
                            steamId: widget.steamId,
                            items: widget.items,
                            currentPrices: _prices,
                            initialPrices: _initialPrices,
                          ),
                        ),
                      )
                  : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _valueBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _green.withAlpha(100), width: 1.5),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Geschätzter Inventarwert',
                            style: TextStyle(
                              color: _green,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _loadingPrices && _totalValue == 0
                              ? const SizedBox(
                                  height: 36,
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: _green,
                                      ),
                                    ),
                                  ),
                                )
                              : Text(
                                  '\$${_totalValue.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                ),
                        ],
                      ),
                    ),
                    if (_initialSet)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D3A18),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _green.withAlpha(80)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isPositive
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              color: _green,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${isPositive ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                color: _green,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── Section label
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'GEGENSTÄNDE',
                  style: TextStyle(
                    color: _textDim,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
                const Spacer(),
                if (_loadingPrices)
                  Row(
                    children: [
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: _textDim,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_prices.length}/${widget.items.length}',
                        style: const TextStyle(
                          color: _textDim,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Item List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = filtered[i];
                final hash = buildMarketHashName(item);
                final price = _prices[hash];
                return _InventoryItemCard(
                  item: item,
                  priceResult: price,
                  loading: _loadingPrices && price == null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Item Card
// ─────────────────────────────────────────
class _InventoryItemCard extends StatelessWidget {
  final Item item;
  final SkinportPriceResult? priceResult;
  final bool loading;

  const _InventoryItemCard({
    required this.item,
    required this.priceResult,
    required this.loading,
  });

  /// Wear aus market_hash_name parsen, z.B. "AK-47 | Redline (Field-Tested)" → "Field-Tested"
  String? get _wear {
    final mhn = item.marketHashName ?? '';
    final match = RegExp(r'\(([^)]+)\)$').firstMatch(mhn);
    return match?.group(1);
  }

  /// Anzeigename ohne Wear-Klammer
  String get _displayName {
    final mhn = item.marketHashName ?? item.name;
    return mhn.replaceAll(RegExp(r'\s*\([^)]+\)$'), '').trim();
  }

  /// StatTrak-Badge
  bool get _isStatTrak => item.name.contains('StatTrak');

  /// Rarity-Farbe (aus Steam-Tags oder Fallback über Name)
  Color get _rarityDotColor {
    final hex = item.rarityColor;
    if (hex != null && hex.isNotEmpty) {
      return Color(int.parse('FF$hex', radix: 16));
    }
    // Fallback: Rarity aus Name ableiten
    final n = item.name.toLowerCase();
    if (n.contains('★') || n.contains('glove') || n.contains('handschuhe')) {
      return const Color(0xFFE4AE39); // Extraordinary (gold)
    }
    if (n.contains('stattrak')) return const Color(0xFFCF6A32); // StatTrak orange
    return _textDim;
  }

  /// Rarity-Label Text
  String get _rarityLabel {
    if (_isStatTrak) return 'STATTRAK™';
    final r = item.rarityName;
    if (r != null && r.isNotEmpty) return r.toUpperCase();
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final price = priceResult?.suggestedPrice;
    final wear = _wear;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder, width: 1),
      ),
      child: Row(
        children: [
          // ── Item Image + Rarity Dot
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: item.image != null
                    ? Image.network(
                        proxyImageUrl(item.image),
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _imageFallback,
                      )
                    : _imageFallback,
              ),
              // Rarity dot
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _rarityDotColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: _cardBg, width: 1.5),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 14),

          // ── Name + Wear
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (wear != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    wear,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _textDim,
                      fontSize: 12,
                    ),
                  ),
                ],
                if (item.amount > 1) ...[
                  const SizedBox(height: 3),
                  Text(
                    'x${item.amount}',
                    style: const TextStyle(
                      color: _textDim,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── Preis + Rarity-Label
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: _textDim,
                  ),
                )
              else if (price != null)
                Text(
                  '\$${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: _green,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                const Text(
                  '—',
                  style: TextStyle(color: _textDim, fontSize: 15),
                ),
              if (_rarityLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _rarityLabel,
                  style: const TextStyle(
                    color: _textDim,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget get _imageFallback => Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF0A1A0A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.image_not_supported_outlined,
            color: _textDim, size: 28),
      );
}

// ─────────────────────────────────────────
// Icon Button
// ─────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _cardBorder, width: 1),
        ),
        child: Icon(icon, color: _green, size: 20),
      ),
    );
  }
}
