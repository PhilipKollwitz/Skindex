import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/market_api.dart';

/// Beispiel-Model – passe den Typ ggf. an dein tatsächliches Modell an.
class CsItem {
  final String name;
  final String marketHashName;
  final String? imageUrl;

  CsItem({
    required this.name,
    required this.marketHashName,
    this.imageUrl,
  });
}

class ItemDetailPage extends StatefulWidget {
  final CsItem item;

  const ItemDetailPage({super.key, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  SkinportItem? _skinport;
  String? _skinportError;
  bool _loadingSkinport = false;

  // ---------- Steam ----------

  Future<void> _openSteamListing() async {
    // marketHashName ist nicht-nullbar -> kein "??" nötig
    final mh = widget.item.marketHashName;
    final url = MarketApi.steamListingUrl(mh);
    final uri = Uri.parse(url);

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
        widget.item.marketHashName,
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
  final mh = widget.item.marketHashName;
  final currency = _skinport?.currency ?? 'EUR';

  final url = MarketApi.skinportListingUrl(
    _skinport,
    mh,
    currency: currency,
  );

  final uri = Uri.parse(url);

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
    final item = widget.item;

    return Scaffold(
      appBar: AppBar(
        title: Text(item.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Linke Seite: Bild
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: item.imageUrl == null
                          ? const Text('Kein Bild vorhanden.')
                          : Image.network(
                              MarketApi.proxyImageUrl(item.imageUrl!),
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stack) =>
                                  const Text('Bild konnte nicht geladen werden'),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.marketHashName,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Rechte Seite: Preise + Buttons
            Expanded(
              flex: 1,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ----- Steam -----
                    OutlinedButton(
                      onPressed: _openSteamListing,
                      child: const Text('Steam Listing im Browser öffnen'),
                    ),
                    const SizedBox(height: 24),

                    // ----- Skinport -----
                    const Text(
                      'Skinport Preis',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    if (_loadingSkinport)
                      const CircularProgressIndicator()
                    else if (_skinportError != null)
                      Text(
                        _skinportError!,
                        style: const TextStyle(color: Colors.red),
                      )
                    else if (_skinport != null)
                      Text(
                        'Min: ${_skinport!.minPrice ?? "-"} ${_skinport!.currency}\n'
                        'Max: ${_skinport!.maxPrice ?? "-"} ${_skinport!.currency}\n'
                        'Suggested: ${_skinport!.suggestedPrice ?? "-"} ${_skinport!.currency}',
                      )
                    else
                      const Text('(noch nicht abgefragt)'),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed:
                          _loadingSkinport ? null : _loadSkinportPrice,
                      child: _loadingSkinport
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Skinport Preis anzeigen'),
                    ),
                    const SizedBox(height: 4),
                    OutlinedButton(
                      onPressed: _openSkinportListing,
                      child: const Text('Skinport Listing im Browser öffnen'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
