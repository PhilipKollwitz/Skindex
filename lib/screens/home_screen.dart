import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'search_screen.dart';
import 'add_inventory_screen.dart';
import 'inventory_list_screen.dart';
import 'market_screen.dart';
import 'profile_screen.dart';
import '../main.dart' show Item, buildMarketHashName, proxyImageUrl;
import '../services/portfolio_storage.dart';

// ── Theme colors
const Color _bg = Color(0xFF060E06);
const Color _cardBg = Color(0xFF0C1A0C);
const Color _green = Color(0xFF4ADE80);
const Color _cardBorder = Color(0xFF1A3520);
const Color _textDim = Color(0xFF6B8A6B);
const Color _red = Color(0xFFEF4444);
const Color _navBg = Color(0xFF070F07);

// ─────────────────────────────────────────
// Root: tab host
// ─────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  String? _steamId;
  List<Item> _inventoryItems = [];
  bool _checkingLinkedInventory = true;
  String _currency = 'EUR';

  @override
  void initState() {
    super.initState();
    _checkLinkedInventory();
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('currency');
    if (saved != null && mounted) setState(() => _currency = saved);
  }

  Future<void> _checkLinkedInventory() async {
    // 1. Zuerst lokal prüfen (SharedPreferences, kein Netz nötig)
    final prefs = await SharedPreferences.getInstance();
    final localSteamId = prefs.getString('linked_steam_id');
    final localItemsJson = prefs.getString('inventory_items');

    if (localSteamId != null && localItemsJson != null) {
      try {
        final list = jsonDecode(localItemsJson) as List;
        final items = list
            .map((m) => Item(
                  id: m['id'] as String? ?? '',
                  name: m['name'] as String? ?? '',
                  typeKey: m['typeKey'] as String? ?? 'skin',
                  image: m['image'] as String?,
                  marketHashName: m['marketHashName'] as String?,
                  amount: (m['amount'] as num?)?.toInt() ?? 1,
                  rarityColor: m['rarityColor'] as String?,
                  rarityName: m['rarityName'] as String?,
                ))
            .toList();
        if (mounted) {
          setState(() {
            _steamId = localSteamId;
            _inventoryItems = items;
          });
        }
      } catch (_) {}
    } else {
      // 2. Kein lokaler Cache → Firestore versuchen (mit Timeout für Ad-Blocker)
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          final steamId = await PortfolioStorage.getSteamIdForUid(uid)
              .timeout(const Duration(seconds: 5));
          if (steamId != null) {
            final items = await PortfolioStorage.loadItems(steamId)
                .timeout(const Duration(seconds: 8));
            if (items != null && items.isNotEmpty && mounted) {
              setState(() {
                _steamId = steamId;
                _inventoryItems = items;
              });
              _saveInventoryLocally(steamId, items);
            }
          }
        } catch (_) {}
      }
    }

    if (mounted) setState(() => _checkingLinkedInventory = false);
  }

  Future<void> _saveInventoryLocally(String steamId, List<Item> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('linked_steam_id', steamId);
    final json = jsonEncode(items
        .map((item) => {
              'id': item.id,
              'name': item.name,
              'typeKey': item.typeKey,
              'image': item.image,
              'marketHashName': item.marketHashName,
              'amount': item.amount,
              'rarityColor': item.rarityColor,
              'rarityName': item.rarityName,
            })
        .toList());
    await prefs.setString('inventory_items', json);
  }

  void _onInventoryLoaded(String steamId, List<Item> items) {
    setState(() {
      _steamId = steamId;
      _inventoryItems = items;
    });
    _saveInventoryLocally(steamId, items);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      PortfolioStorage.linkUidToSteamId(uid, steamId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    if (_checkingLinkedInventory) {
      return const Scaffold(
        backgroundColor: Color(0xFF060E06),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF4ADE80)),
        ),
      );
    }

    final tabs = [
      _HomeTab(
        steamId: _steamId,
        inventoryItems: _inventoryItems,
        onSearchTap: () => setState(() => _index = 1),
        onInventoryTap: () => setState(() => _index = 2),
        onMarketTap: () => setState(() => _index = 3),
      ),
      SearchScreen(currency: _currency),
      _steamId != null
          ? InventoryListScreen(
              steamId: _steamId!,
              items: _inventoryItems,
              currency: _currency,
              onBack: () => setState(() => _index = 0),
            )
          : InventorySetupScreen(onInventoryLoaded: _onInventoryLoaded),
      MarketScreen(currency: _currency),
      ProfileScreen(
        steamId: _steamId,
        currency: _currency,
        onCurrencyChanged: (c) async {
          setState(() => _currency = c);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('currency', c);
        },
        onRemoveInventory: () => setState(() {
          _steamId = null;
          _inventoryItems = [];
        }),
      ),
    ];
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: _BottomNav(
        selectedIndex: _index,
        onTap: (i) => setState(() => _index = i),
        bottomPad: bottomPad,
      ),
    );
  }
}

// ─────────────────────────────────────────
// Bottom Navigation
// ─────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final double bottomPad;

  const _BottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.bottomPad,
  });

  static const _items = [
    (icon: Icons.home_rounded, label: 'HOME'),
    (icon: Icons.search_rounded, label: 'SUCHEN'),
    (icon: Icons.inventory_2_outlined, label: 'INVENTAR'),
    (icon: Icons.grid_view_rounded, label: 'MARKT'),
    (icon: Icons.person_outline_rounded, label: 'PROFIL'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _navBg,
        border: Border(top: BorderSide(color: Color(0xFF1A3520), width: 1)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPad, top: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final active = selectedIndex == i;
            return GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      color: active ? _green : _textDim,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: TextStyle(
                        color: active ? _green : _textDim,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// HOME Tab (StatefulWidget for data loading)
// ─────────────────────────────────────────
class _HomeTab extends StatefulWidget {
  final String? steamId;
  final List<Item> inventoryItems;
  final VoidCallback onSearchTap;
  final VoidCallback onInventoryTap;
  final VoidCallback onMarketTap;

  const _HomeTab({
    required this.steamId,
    required this.inventoryItems,
    required this.onSearchTap,
    required this.onInventoryTap,
    required this.onMarketTap,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  double? _latestValue;
  double? _change24h;
  List<_MoverItem> _topMovers = [];
  bool _loadingData = false;

  @override
  void initState() {
    super.initState();
    if (widget.steamId != null) _loadData();
  }

  @override
  void didUpdateWidget(_HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.steamId != widget.steamId && widget.steamId != null) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (widget.steamId == null) return;
    setState(() => _loadingData = true);

    try {
      // Letzten 2 Snapshots für 24h-Änderung
      final history = await PortfolioStorage.loadValueHistory(widget.steamId!)
          .timeout(const Duration(seconds: 5));

      double? latestValue;
      double? change24h;
      if (history.isNotEmpty) {
        latestValue = history.last.totalValue;
        if (history.length >= 2) {
          change24h = latestValue - history[history.length - 2].totalValue;
        }
      }

      // Top-Mover: initialPrices vs. letzter Cron-Snapshot
      final initialPrices =
          await PortfolioStorage.loadInitialPrices(widget.steamId!)
              .timeout(const Duration(seconds: 5));
      final latestSnap =
          await PortfolioStorage.loadLatestItemSnapshot(widget.steamId!)
              .timeout(const Duration(seconds: 5));

      final movers = <_MoverItem>[];
      if (initialPrices != null &&
          latestSnap != null &&
          latestSnap.itemPrices.isNotEmpty) {
        for (final item in widget.inventoryItems) {
          final hash = buildMarketHashName(item);
          final initial = initialPrices[hash];
          final current = latestSnap.itemPrices[hash];
          if (initial != null && current != null && initial > 0) {
            final pct = (current - initial) / initial * 100;
            if (pct.abs() >= 0.5) {
              movers.add(_MoverItem(
                name: item.name,
                changePercent: pct,
                currentPrice: current,
                imageUrl: item.image,
              ));
            }
          }
        }
        movers.sort(
            (a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()));
      }

      if (mounted) {
        setState(() {
          _latestValue = latestValue;
          _change24h = change24h;
          _topMovers = movers.take(3).toList();
          _loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: topPad + 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _Header(),
          ),

          const SizedBox(height: 20),

          // Items suchen card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SearchCard(onTap: widget.onSearchTap),
          ),

          const SizedBox(height: 12),

          // Mein Inventar card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _InventarCard(
              onTap: widget.onInventoryTap,
              itemCount: widget.inventoryItems.length,
              totalValue: _latestValue,
              change24h: _change24h,
              hasInventory: widget.steamId != null,
            ),
          ),

          const SizedBox(height: 24),

          // Markt-Heatmap
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _HeatmapSection(
              onTap: widget.onMarketTap,
              topMovers: _topMovers,
              isLoading: _loadingData,
              hasInventory: widget.steamId != null,
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _MoverItem {
  final String name;
  final double changePercent;
  final double currentPrice;
  final String? imageUrl;

  const _MoverItem({
    required this.name,
    required this.changePercent,
    required this.currentPrice,
    required this.imageUrl,
  });
}

// ─────────────────────────────────────────
// Header
// ─────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final displayName =
        user?.displayName ?? user?.email?.split('@').first ?? 'Nutzer';
    final photoUrl = user?.photoURL;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // App logo
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'assets/images/logo.png',
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B00), Color(0xFFFFD600)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child:
                  const Icon(Icons.whatshot, color: Colors.white, size: 24),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Avatar
        Stack(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _green, width: 2),
                color: const Color(0xFF1A3520),
              ),
              child: ClipOval(
                child: photoUrl != null
                    ? Image.network(
                        photoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.person, color: _green, size: 26),
                      )
                    : const Icon(Icons.person, color: _green, size: 26),
              ),
            ),
            // Online dot
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: _green,
                  shape: BoxShape.circle,
                  border: Border.all(color: _bg, width: 2),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(width: 12),

        // Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WILLKOMMEN',
                style: TextStyle(
                  color: _green,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// ─────────────────────────────────────────
// Items suchen card
// ─────────────────────────────────────────
class _SearchCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GreenIconBox(icon: Icons.search_rounded),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: _textDim, size: 26),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Items suchen',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Muster, Floats und Marktpreise prüfen.',
              style: TextStyle(color: _textDim, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Mein Inventar card
// ─────────────────────────────────────────
class _InventarCard extends StatelessWidget {
  final VoidCallback onTap;
  final int itemCount;
  final double? totalValue;
  final double? change24h;
  final bool hasInventory;

  const _InventarCard({
    required this.onTap,
    required this.itemCount,
    required this.hasInventory,
    this.totalValue,
    this.change24h,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GreenIconBox(icon: Icons.inventory_2_rounded),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    color: _textDim, size: 26),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Mein Inventar',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasInventory && itemCount > 0) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _green,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$itemCount',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              hasInventory
                  ? 'Gesamtwert, ROI und Wertsteigerung verfolgen.'
                  : 'Füge dein Inventar hinzu um es hier zu sehen.',
              style: const TextStyle(
                  color: _textDim, fontSize: 14, height: 1.4),
            ),
            if (hasInventory) ...[
              const SizedBox(height: 20),
              const Divider(color: Color(0xFF1A3520), thickness: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GESCHÄTZTER WERT',
                          style: TextStyle(
                            color: _green,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          totalValue != null
                              ? '\$${totalValue!.toStringAsFixed(2)}'
                              : '—',
                          style: const TextStyle(
                            color: _green,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '24H ÄNDERUNG',
                        style: TextStyle(
                          color: _textDim,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        change24h != null
                            ? '${change24h! >= 0 ? '+' : ''}\$${change24h!.toStringAsFixed(2)}'
                            : '—',
                        style: TextStyle(
                          color: change24h != null && change24h! < 0
                              ? _red
                              : _green,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Markt-Heatmap section
// ─────────────────────────────────────────
class _HeatmapSection extends StatelessWidget {
  final VoidCallback onTap;
  final List<_MoverItem> topMovers;
  final bool isLoading;
  final bool hasInventory;

  const _HeatmapSection({
    required this.onTap,
    required this.topMovers,
    required this.isLoading,
    required this.hasInventory,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'TOP MOVER',
              style: TextStyle(
                color: _green,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: onTap,
              child: const Text(
                'ALLE ANZEIGEN',
                style: TextStyle(
                  color: _textDim,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorder, width: 1),
            ),
            child: isLoading
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: _green, strokeWidth: 2),
                      ),
                    ),
                  )
                : !hasInventory || topMovers.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Icon(Icons.show_chart_rounded,
                                color: _textDim, size: 32),
                            const SizedBox(height: 12),
                            Text(
                              hasInventory
                                  ? 'Öffne dein Inventar um\nPreisveränderungen zu laden.'
                                  : 'Kein Inventar verknüpft.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: _textDim, fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: List.generate(topMovers.length, (i) {
                          final item = topMovers[i];
                          return Column(
                            children: [
                              _HeatmapRow(item: item),
                              if (i < topMovers.length - 1)
                                const Divider(
                                  color: Color(0xFF1A3520),
                                  height: 1,
                                  indent: 16,
                                  endIndent: 16,
                                ),
                            ],
                          );
                        }),
                      ),
          ),
        ),
      ],
    );
  }
}

class _HeatmapRow extends StatelessWidget {
  final _MoverItem item;
  const _HeatmapRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final isPositive = item.changePercent >= 0;
    final color = isPositive ? _green : _red;
    final pctStr =
        '${isPositive ? '+' : ''}${item.changePercent.toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          // Left accent bar
          Container(
            width: 3,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),

          // Item image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.imageUrl != null
                ? Image.network(
                    proxyImageUrl(item.imageUrl),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _imgPlaceholder(),
                  )
                : _imgPlaceholder(),
          ),
          const SizedBox(width: 12),

          // Name + price
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${item.currentPrice.toStringAsFixed(2)}',
                  style: TextStyle(color: _textDim, fontSize: 12),
                ),
              ],
            ),
          ),

          // % change + trend icon
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(
                isPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                color: color,
                size: 22,
              ),
              const SizedBox(height: 2),
              Text(
                pctStr,
                style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF1A3520),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.image_not_supported_outlined,
            color: _textDim, size: 22),
      );
}

// ─────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder, width: 1),
      ),
      child: child,
    );
  }
}

class _GreenIconBox extends StatelessWidget {
  final IconData icon;
  const _GreenIconBox({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.black, size: 28),
    );
  }
}

