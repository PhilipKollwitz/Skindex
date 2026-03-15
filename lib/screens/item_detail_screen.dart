import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart' as app;
import '../services/market_api.dart';

// ── Colors (same dark-green palette)
const Color _bg = Color(0xFF060E06);
const Color _cardBg = Color(0xFF0C1A0C);
const Color _green = Color(0xFF4ADE80);
const Color _cardBorder = Color(0xFF1A3520);
const Color _textDim = Color(0xFF6B8A6B);

class ItemDetailScreen extends StatefulWidget {
  final app.Item item;

  const ItemDetailScreen({super.key, required this.item});

  @override
  State<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends State<ItemDetailScreen> {
  late String _selectedWear;
  Future<SkinportItem>? _priceFuture;
  DateTime _priceLoadedAt = DateTime.now();

  // Holds the last successfully fetched SkinportItem for the bottom sheet
  SkinportItem? _lastPrice;

  @override
  void initState() {
    super.initState();
    _selectedWear =
        widget.item.wears.isNotEmpty ? widget.item.wears.first : '';
    _fetchPrice();
  }

  void _fetchPrice() {
    setState(() {
      _priceLoadedAt = DateTime.now();
      _priceFuture = MarketApi.fetchSkinportPrice(_mhn);
      _priceFuture!.then((p) {
        if (mounted) setState(() => _lastPrice = p);
      }).catchError((_) {});
    });
  }

  String get _mhn {
    if (widget.item.typeKey == 'skin' && _selectedWear.isNotEmpty) {
      return '${widget.item.name} ($_selectedWear)';
    }
    return widget.item.marketHashName ?? widget.item.name;
  }

  void _selectWear(String wear) {
    if (wear == _selectedWear) return;
    setState(() => _selectedWear = wear);
    _fetchPrice();
  }

  void _openOffersSheet() {
    final steamUrl = app.buildMarketUrl(_mhn);
    final skinportUrl = MarketApi.skinportListingUrl(_lastPrice, _mhn);

    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _OffersSheet(
        steamUrl: steamUrl,
        skinportUrl: skinportUrl,
        wear: _selectedWear,
      ),
    );
  }

  // Returns minutes since last price fetch as a string
  String get _lastUpdated {
    final mins = DateTime.now().difference(_priceLoadedAt).inMinutes;
    if (mins < 1) return 'Gerade eben';
    return 'Vor $mins Minute${mins == 1 ? '' : 'n'}';
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final parts = widget.item.name.split(' | ');
    final weaponType = parts.length > 1 ? parts[0] : '';

    final imgUrl = widget.item.image != null
        ? app.proxyImageUrl(widget.item.image)
        : null;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Custom header (no AppBar to keep style)
          SizedBox(height: topPad + 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Back
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Item-Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {},
                  child: const Icon(Icons.share_outlined,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () {},
                  child: const Icon(Icons.star_border_rounded,
                      color: Colors.white, size: 24),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Scrollable body
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomPad + 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Item image
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _ItemImageCard(imgUrl: imgUrl),
                  ),

                  const SizedBox(height: 20),

                  // ── Name + type
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        if (weaponType.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            weaponType,
                            style: const TextStyle(
                              color: _green,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // ── Wear selector
                  if (widget.item.wears.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        'ZUSTAND WÄHLEN',
                        style: TextStyle(
                          color: _textDim,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: widget.item.wears.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final wear = widget.item.wears[i];
                          final active = wear == _selectedWear;
                          return GestureDetector(
                            onTap: () => _selectWear(wear),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    active ? _green.withAlpha(30) : _cardBg,
                                border: Border.all(
                                  color: active ? _green : _cardBorder,
                                  width: active ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                wear,
                                style: TextStyle(
                                  color: active ? _green : _textDim,
                                  fontSize: 13,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // ── Price card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _PriceCard(
                      priceFuture: _priceFuture,
                      lastUpdated: _lastUpdated,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── "Angebote öffnen" button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _openOffersSheet,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text(
                          'Angebote öffnen',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Item image card
// ─────────────────────────────────────────
class _ItemImageCard extends StatelessWidget {
  final String? imgUrl;
  const _ItemImageCard({required this.imgUrl});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _cardBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: imgUrl != null
            ? Image.network(
                imgUrl!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => const _ImgPlaceholder(),
              )
            : const _ImgPlaceholder(),
      ),
    );
  }
}

class _ImgPlaceholder extends StatelessWidget {
  const _ImgPlaceholder();
  @override
  Widget build(BuildContext context) => const Center(
        child: Icon(Icons.image_not_supported_outlined,
            color: _textDim, size: 48),
      );
}

// ─────────────────────────────────────────
// Price card
// ─────────────────────────────────────────
class _PriceCard extends StatelessWidget {
  final Future<SkinportItem>? priceFuture;
  final String lastUpdated;

  const _PriceCard({required this.priceFuture, required this.lastUpdated});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _cardBorder, width: 1),
      ),
      child: FutureBuilder<SkinportItem>(
        future: priceFuture,
        builder: (ctx, snap) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E3A1E),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.storefront_outlined,
                        color: _green, size: 13),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Skinport Live-Preis',
                    style: TextStyle(
                      color: _textDim,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.trending_up_rounded,
                    color: snap.hasData ? _green : _textDim,
                    size: 20,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Price
              if (snap.connectionState == ConnectionState.waiting)
                const SizedBox(
                  height: 40,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: _green, strokeWidth: 2),
                  ),
                )
              else if (snap.hasData && snap.data!.suggestedPrice != null)
                Text(
                  '\$${snap.data!.suggestedPrice!.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                )
              else
                const Text(
                  'Kein Preis verfügbar',
                  style: TextStyle(color: _textDim, fontSize: 16),
                ),

              const SizedBox(height: 8),

              Text(
                lastUpdated,
                style: const TextStyle(color: _textDim, fontSize: 12),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────
// Offers bottom sheet
// ─────────────────────────────────────────
class _OffersSheet extends StatelessWidget {
  final String steamUrl;
  final String skinportUrl;
  final String wear;

  const _OffersSheet({
    required this.steamUrl,
    required this.skinportUrl,
    required this.wear,
  });

  Future<void> _open(BuildContext ctx, String url) async {
    Navigator.of(ctx).pop();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPad),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF374151),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Marktplatz wählen',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            wear.isNotEmpty ? 'Zustand: $wear' : 'Angebote öffnen',
            style: const TextStyle(color: _textDim, fontSize: 13),
          ),

          const SizedBox(height: 24),

          // Steam button
          _MarketButton(
            icon: Icons.gamepad_rounded,
            iconColor: const Color(0xFF4B91C9),
            label: 'Steam Market',
            subtitle: 'Offizielle Steam-Listings',
            onTap: () => _open(context, steamUrl),
          ),

          const SizedBox(height: 12),

          // Skinport button
          _MarketButton(
            icon: Icons.storefront_rounded,
            iconColor: _green,
            label: 'Skinport',
            subtitle: 'Günstigere Drittanbieter-Listings',
            onTap: () => _open(context, skinportUrl),
          ),
        ],
      ),
    );
  }
}

class _MarketButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _MarketButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F1F0F),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _cardBorder, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: _textDim, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: _textDim, size: 14),
          ],
        ),
      ),
    );
  }
}
