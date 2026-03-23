import 'package:flutter/material.dart';
import '../services/market_api.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' show currencySymbol;

// ── Theme colors (identisch mit anderen Screens)
const Color _bg = Color(0xFF060E06);
const Color _cardBg = Color(0xFF0C1A0C);
const Color _green = Color(0xFF4ADE80);
const Color _cardBorder = Color(0xFF1A3520);
const Color _textDim = Color(0xFF6B8A6B);
const Color _red = Color(0xFFEF4444);

// ─────────────────────────────────────────
// Market Screen
// ─────────────────────────────────────────
class MarketScreen extends StatefulWidget {
  final String currency;
  const MarketScreen({super.key, this.currency = 'EUR'});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  List<MarketDeal> _deals = [];
  List<MarketTrend> _trending = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await MarketApi.fetchMarketData(currency: widget.currency);
      if (mounted) {
        setState(() {
          _deals = data.deals;
          _trending = data.trending;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: _green))
                  : _error != null
                      ? _buildError()
                      : RefreshIndicator(
                          color: _green,
                          backgroundColor: _cardBg,
                          onRefresh: _loadData,
                          child: ListView(
                            padding: const EdgeInsets.only(bottom: 24),
                            children: [
                              _buildMarktTrends(),
                              _buildLiveAngebote(),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.search, color: _green, size: 24),
          const Expanded(
            child: Text(
              'Markt',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _red, size: 48),
          const SizedBox(height: 12),
          Text(
            'Fehler beim Laden',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 4),
          Text(
            _error ?? '',
            style: const TextStyle(color: _textDim, fontSize: 11),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _loadData,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Erneut versuchen',
                style: TextStyle(
                    color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Markt-Trends ──────────────────────────────────────────────────────────

  Widget _buildMarktTrends() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                const Icon(Icons.trending_up, color: _green, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'Markt-Trends',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                ),
              ]),
              const Text(
                'ALLE ANSEHEN',
                style: TextStyle(
                    color: _green, fontSize: 11, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 162,
          child: _trending.isEmpty
              ? const Center(
                  child: Text('Keine Daten',
                      style: TextStyle(color: _textDim)))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _trending.length,
                  itemBuilder: (_, i) => _TrendCard(item: _trending[i], currency: widget.currency),
                ),
        ),
      ],
    );
  }


  // ── Live-Angebote ─────────────────────────────────────────────────────────

  Widget _buildLiveAngebote() {
    final deals = _deals;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              const Icon(Icons.wifi_tethering, color: _green, size: 18),
              const SizedBox(width: 8),
              const Text(
                'Live-Angebote',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: _green, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
        if (deals.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('Keine Angebote in dieser Kategorie',
                  style: TextStyle(color: _textDim)),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: deals.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _DealCard(deal: deals[i], currency: widget.currency, onTap: () {
              final url = MarketApi.skinportListingUrl(null, deals[i].marketHashName);
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            }),
          ),
      ],
    );
  }

}

// ─────────────────────────────────────────
// Trend Card (horizontal scroll)
// ─────────────────────────────────────────
class _TrendCard extends StatelessWidget {
  final MarketTrend item;
  final String currency;
  const _TrendCard({required this.item, required this.currency});

  @override
  Widget build(BuildContext context) {
    // discountPct > 0 → min_price liegt UNTER suggested → Preis gefallen
    final fell = item.discountPct > 2;
    final pctLabel = '${item.discountPct.abs()}%';

    return Container(
      width: 150,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bild
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 80,
              width: double.infinity,
              child: item.iconUrl != null
                  ? Image.network(
                      MarketApi.proxyImageUrl(item.iconUrl!),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => _imgPlaceholder(),
                    )
                  : _imgPlaceholder(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shortName(item.marketHashName),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // % Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: fell
                            ? const Color(0xFF450A0A)
                            : const Color(0xFF14532D),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            fell
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            size: 10,
                            color: fell ? _red : _green,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            pctLabel,
                            style: TextStyle(
                              color: fell ? _red : _green,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${currencySymbol(currency)}${item.suggestedPrice.toStringAsFixed(0)}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        color: const Color(0xFF060E06),
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: Color(0xFF1A3520), size: 28),
        ),
      );

  String _shortName(String name) {
    final idx = name.indexOf(' (');
    return idx > 0 ? name.substring(0, idx) : name;
  }
}

// ─────────────────────────────────────────
// Deal Card (Live-Angebote)
// ─────────────────────────────────────────
class _DealCard extends StatelessWidget {
  final MarketDeal deal;
  final String currency;
  final VoidCallback? onTap;
  const _DealCard({required this.deal, required this.currency, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: _cardBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Bild
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF060E06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: deal.iconUrl != null
                  ? Image.network(
                      MarketApi.proxyImageUrl(deal.iconUrl!),
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => _imgPlaceholder(),
                    )
                  : _imgPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          // Name + Wear + Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _shortName(deal.marketHashName),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _wearText(deal.marketHashName),
                  style:
                      const TextStyle(color: _textDim, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildBadge(),
                    if (_timeAgo() != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo()!,
                        style: const TextStyle(
                            color: _textDim, fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Preis
          Text(
            '${currencySymbol(currency)}${deal.minPrice.toStringAsFixed(2)}',
            style: const TextStyle(
                color: _green,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
        ],
      ),
    ));
  }

  Widget _buildBadge() {
    if (deal.discountPct >= 12) {
      return _Badge('-${deal.discountPct}% Market',
          const Color(0xFF7F1D1D), _red);
    } else if (deal.discountPct >= 7) {
      return _Badge(
          'Good Deal', const Color(0xFF14532D), _green);
    } else if (deal.suggestedPrice > 500) {
      return _Badge(
          'Rare Skin', const Color(0xFF4C1D95), const Color(0xFFA78BFA));
    }
    return _Badge(
        '-${deal.discountPct}% Rabatt', const Color(0xFF14532D), _green);
  }

  Widget _imgPlaceholder() => const Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: Color(0xFF1A3520), size: 22),
      );

  String _shortName(String name) {
    final idx = name.indexOf(' (');
    return idx > 0 ? name.substring(0, idx) : name;
  }

  String _wearText(String name) {
    final match = RegExp(r'\(([^)]+)\)$').firstMatch(name);
    return match?.group(1) ?? '';
  }

  String? _timeAgo() {
    if (deal.updatedAt == null) return null;
    final diff = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(deal.updatedAt! * 1000));
    if (diff.inMinutes < 1) return 'Gerade';
    if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
    if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
    return 'vor ${diff.inDays} Tagen';
  }
}

// ─────────────────────────────────────────
// Badge Widget
// ─────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge(this.label, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(label,
          style: TextStyle(
              color: fg, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
