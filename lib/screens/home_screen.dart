import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'add_inventory_screen.dart';
import '../main.dart' show Item;

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
  // ignore: unused_field
  String? _steamId;
  // ignore: unused_field
  List<Item> _inventoryItems = [];

  void _onInventoryLoaded(String steamId, List<Item> items) {
    setState(() {
      _steamId = steamId;
      _inventoryItems = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final tabs = [
      const _HomeTab(),
      const SearchScreen(),
      InventorySetupScreen(onInventoryLoaded: _onInventoryLoaded),
      const _PlaceholderTab(label: 'Markt', icon: Icons.grid_view_rounded),
      const _PlaceholderTab(label: 'Profil', icon: Icons.person_outline),
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
// HOME Tab
// ─────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();

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

          // Market ticker
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _MarketTicker(),
          ),

          const SizedBox(height: 20),

          // Items suchen card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SearchCard(),
          ),

          const SizedBox(height: 12),

          // Mein Inventar card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _InventarCard(),
          ),

          const SizedBox(height: 24),

          // Markt-Heatmap
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _HeatmapSection(),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Header
// ─────────────────────────────────────────
class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
              child: const Icon(Icons.whatshot, color: Colors.white, size: 24),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Avatar + welcome
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
              child: const Icon(Icons.person, color: _green, size: 26),
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
                'AKTIVER AGENT',
                style: TextStyle(
                  color: _green,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Willkommen, Global Elite',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),

        // Bell
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.notifications_outlined, color: Colors.black, size: 22),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Market Ticker
// ─────────────────────────────────────────
class _MarketTicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TickerPill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.show_chart_rounded, color: _green, size: 16),
              SizedBox(width: 6),
              Text('MARKT', style: _tickerLabelStyle),
              SizedBox(width: 6),
              Text('↑2.4%', style: TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.w700)),
              SizedBox(width: 6),
              Text('MARKT +2.4%', style: _tickerLabelStyle),
            ],
          ),
        ),
        const SizedBox(width: 10),
        _TickerPill(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.history_rounded, color: _green, size: 14),
              SizedBox(width: 6),
              Text('VOR 2', style: _tickerLabelStyle),
            ],
          ),
        ),
      ],
    );
  }
}

const _tickerLabelStyle = TextStyle(
  color: _green,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.5,
);

class _TickerPill extends StatelessWidget {
  final Widget child;
  const _TickerPill({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: _cardBorder, width: 1.5),
        borderRadius: BorderRadius.circular(50),
        color: _cardBg,
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────
// Items suchen card
// ─────────────────────────────────────────
class _SearchCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GreenIconBox(icon: Icons.search_rounded),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: _textDim, size: 26),
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: const [
              _Chip('KNIVES'),
              _Chip('GLOVES'),
              _Chip('CASES'),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Mein Inventar card
// ─────────────────────────────────────────
class _InventarCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _GreenIconBox(icon: Icons.inventory_2_rounded),
              const Spacer(),
              const Icon(Icons.chevron_right_rounded, color: _textDim, size: 26),
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
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '42',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Gesamtwert, ROI und Wertsteigerung verfolgen.',
            style: TextStyle(color: _textDim, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFF1A3520), thickness: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'GESCHÄTZTER WERT',
                      style: TextStyle(
                        color: _green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '\$12,450.00',
                      style: TextStyle(
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
                children: const [
                  Text(
                    '24H ÄNDERUNG',
                    style: TextStyle(
                      color: _textDim,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '+\$124.50',
                    style: TextStyle(
                      color: _green,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Markt-Heatmap section
// ─────────────────────────────────────────
class _HeatmapSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      _HeatmapItem(
        name: 'AWP | Dragon Lore',
        wear: 'Factory New',
        change: '+\$450.00',
        isPositive: true,
        imageUrl:
            'https://community.cloudflare.steamstatic.com/economy/image/-9a81dlWLwJ2UUGcVs_nsVtzdOEdtWwKGZZLQHTxDZ7I4lkMEsumr-BuE0MRiJWTxPaRqFc_GZQLoBBSH5bEv5NupMIVlG5kKA5Wubs7BAZjweTOd2gdvY6wkNiNwvKlYu-HxxRlj5Ep0-mQ84703gzl_UdlZg',
      ),
      _HeatmapItem(
        name: 'Butterfly Knife | Fade',
        wear: 'Minimal Wear',
        change: '-\$12.40',
        isPositive: false,
        imageUrl:
            'https://community.cloudflare.steamstatic.com/economy/image/-9a81dlWLwJ2UUGcVs_nsVtzdOEdtWwKGZZLQHTxDZ7I4lkMEsumr-BuE0MRiJWTxPaRqFc_GZQLoBBSH5bEv5NupMIVlG5kKA5Wubs7BAZjweTOd2gdvY6wkNOKwv-lYe-Hxxj4McpjjryXpt-g0Fbs_0tlYQ',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'MARKT-HEATMAP',
              style: TextStyle(
                color: _green,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {},
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
        Container(
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _cardBorder, width: 1),
          ),
          child: Column(
            children: List.generate(items.length, (i) {
              final item = items[i];
              return Column(
                children: [
                  item,
                  if (i < items.length - 1)
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
      ],
    );
  }
}

class _HeatmapItem extends StatelessWidget {
  final String name;
  final String wear;
  final String change;
  final bool isPositive;
  final String imageUrl;

  const _HeatmapItem({
    required this.name,
    required this.wear,
    required this.change,
    required this.isPositive,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPositive ? _green : _red;

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
            child: Image.network(
              imageUrl,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 52,
                height: 52,
                color: const Color(0xFF1A3520),
                child: const Icon(Icons.image_not_supported_outlined, color: _textDim, size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + wear
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$wear • $change',
                  style: TextStyle(color: _textDim, fontSize: 12),
                ),
              ],
            ),
          ),

          // Trend icon
          Icon(
            isPositive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            color: color,
            size: 24,
          ),
        ],
      ),
    );
  }
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

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: _cardBorder, width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _green,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Placeholder tabs
// ─────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PlaceholderTab({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _textDim, size: 48),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              color: _textDim,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Demnächst verfügbar',
            style: TextStyle(color: Color(0xFF3A5A3A), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
