import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../main.dart' show Item, SkinportPriceResult, buildMarketHashName, proxyImageUrl;
import '../services/portfolio_storage.dart';

// ── Theme colors
const Color _bg = Color(0xFF060E06);
const Color _cardBg = Color(0xFF0C1A0C);
const Color _green = Color(0xFF4ADE80);
const Color _cardBorder = Color(0xFF1A3520);
const Color _textDim = Color(0xFF6B8A6B);
const Color _red = Color(0xFFEF4444);

// ─────────────────────────────────────────
// Portfolio Screen
// ─────────────────────────────────────────
class PortfolioScreen extends StatefulWidget {
  final String steamId;
  final List<Item> items;
  final Map<String, SkinportPriceResult> currentPrices;
  final Map<String, double> initialPrices; // marketHashName → initial price

  const PortfolioScreen({
    super.key,
    required this.steamId,
    required this.items,
    required this.currentPrices,
    required this.initialPrices,
  });

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

enum _TimeRange { d1, w1, m1, m3, all }

class _PortfolioScreenState extends State<PortfolioScreen> {
  _TimeRange _range = _TimeRange.d1;
  List<ValueSnapshot> _history = [];
  bool _loadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await PortfolioStorage.loadValueHistory(widget.steamId);
    if (mounted) {
      setState(() {
        _history = history;
        _loadingHistory = false;
      });
    }
  }

  double get _currentTotal {
    double sum = 0;
    for (final item in widget.items) {
      final hash = buildMarketHashName(item);
      final price = widget.currentPrices[hash]?.suggestedPrice;
      if (price != null) sum += price * item.amount;
    }
    return sum;
  }

  double get _initialTotal {
    double sum = 0;
    for (final item in widget.items) {
      final hash = buildMarketHashName(item);
      final price = widget.initialPrices[hash];
      if (price != null) sum += price * item.amount;
    }
    return sum;
  }

  // Erster Datenpunkt im gewählten Zeitraum (für dynamische Veränderung)
  double? get _rangeStartValue {
    final filtered = _filteredHistory;
    if (filtered.isEmpty) return null;
    return filtered.first.totalValue;
  }

  double get _changeValue {
    final base = _rangeStartValue;
    if (base != null) return _currentTotal - base;
    return _currentTotal - _initialTotal;
  }

  double get _changePercent {
    final base = _rangeStartValue ?? _initialTotal;
    return base > 0 ? (_changeValue / base) * 100 : 0;
  }

  String get _changeLabel {
    switch (_range) {
      case _TimeRange.d1:
        return 'letzte 24h';
      case _TimeRange.w1:
        return 'letzte 7 Tage';
      case _TimeRange.m1:
        return 'letzter Monat';
      case _TimeRange.m3:
        return 'letzte 3 Monate';
      case _TimeRange.all:
        return 'seit Ersteinlesen';
    }
  }

  List<ValueSnapshot> get _filteredHistory {
    if (_history.isEmpty) return [];
    final now = DateTime.now();
    DateTime cutoff;
    switch (_range) {
      case _TimeRange.d1:
        cutoff = now.subtract(const Duration(days: 1));
      case _TimeRange.w1:
        cutoff = now.subtract(const Duration(days: 7));
      case _TimeRange.m1:
        cutoff = now.subtract(const Duration(days: 30));
      case _TimeRange.m3:
        cutoff = now.subtract(const Duration(days: 90));
      case _TimeRange.all:
        return _history;
    }
    final filtered =
        _history.where((s) => s.timestamp.isAfter(cutoff)).toList();
    return filtered.isEmpty ? [_history.last] : filtered;
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final isPositive = _changeValue >= 0;
    final current = _currentTotal;
    final filtered = _filteredHistory;

    return Container(
      color: _bg,
      child: Column(
        children: [
          SizedBox(height: topPad),

          // ── Header
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: _cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _cardBorder),
                    ),
                    child: const Icon(Icons.menu_rounded,
                        color: _green, size: 20),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      'Portfolio',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 42), // Balance
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Value Display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gesamtinventarwert',
                  style: TextStyle(
                    color: _textDim,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '\$${current.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.bold,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isPositive
                            ? const Color(0xFF0D3A18)
                            : const Color(0xFF3A0D0D),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPositive
                              ? _green.withAlpha(80)
                              : _red.withAlpha(80),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                            color: isPositive ? _green : _red,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${isPositive ? '+' : ''}\$${_changeValue.abs().toStringAsFixed(2)} (${_changePercent.abs().toStringAsFixed(2)}%)',
                            style: TextStyle(
                              color: isPositive ? _green : _red,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _changeLabel,
                      style: const TextStyle(color: _textDim, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Time Range Selector
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: _TimeRange.values.map((r) {
                final active = r == _range;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _range = r),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? _green : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          _rangeLabel(r),
                          style: TextStyle(
                            color: active ? Colors.black : _textDim,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 12),

          // ── Chart
          SizedBox(
            height: 160,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _loadingHistory
                  ? const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _green))
                  : filtered.length < 2
                      ? _emptyChart(current)
                      : _buildChart(filtered),
            ),
          ),

          const SizedBox(height: 20),

          // ── Asset Performance
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Asset-Performance',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'Alle anzeigen →',
                    style: TextStyle(
                      color: _green,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Item List
          Expanded(
            child: _buildAssetList(),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}';
  }

  Widget _buildChart(List<ValueSnapshot> data) {
    final minVal = data.map((s) => s.totalValue).reduce((a, b) => a < b ? a : b);
    final maxVal = data.map((s) => s.totalValue).reduce((a, b) => a > b ? a : b);
    final padding = (maxVal - minVal) * 0.15 + 1;
    final lastIdx = (data.length - 1).toDouble();

    final spots = data.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.totalValue);
    }).toList();

    return LineChart(
      LineChartData(
        minY: minVal - padding,
        maxY: maxVal + padding,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: lastIdx > 0 ? lastIdx : 1,
              getTitlesWidget: (value, meta) {
                String label = '';
                if (value == 0) {
                  label = _fmtDate(data.first.timestamp);
                } else if (value == lastIdx) {
                  label = _fmtDate(data.last.timestamp);
                } else {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label,
                      style: const TextStyle(color: _textDim, fontSize: 10)),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF0D2A14),
            getTooltipItems: (spots) => spots
                .map((s) => LineTooltipItem(
                      '\$${s.y.toStringAsFixed(2)}',
                      const TextStyle(
                          color: _green,
                          fontSize: 12,
                          fontWeight: FontWeight.bold),
                    ))
                .toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: _green,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  _green.withAlpha(80),
                  _green.withAlpha(0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyChart(double currentValue) {
    // Platzhalter wenn nicht genug History-Daten
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: [FlSpot(0, currentValue), FlSpot(1, currentValue)],
            isCurved: false,
            color: _green.withAlpha(80),
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [_green.withAlpha(40), _green.withAlpha(0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetList() {
    // Items sortiert nach aktuellem Wert (absteigend)
    final sorted = [...widget.items];
    sorted.sort((a, b) {
      final pa = widget.currentPrices[buildMarketHashName(a)]?.suggestedPrice ?? 0;
      final pb = widget.currentPrices[buildMarketHashName(b)]?.suggestedPrice ?? 0;
      return pb.compareTo(pa);
    });

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final item = sorted[i];
        final hash = buildMarketHashName(item);
        final currentPrice =
            widget.currentPrices[hash]?.suggestedPrice;
        final initialPrice = widget.initialPrices[hash];

        double? changePercent;
        if (currentPrice != null &&
            initialPrice != null &&
            initialPrice > 0) {
          changePercent =
              ((currentPrice - initialPrice) / initialPrice) * 100;
        }

        return _AssetRow(
          item: item,
          currentPrice: currentPrice,
          changePercent: changePercent,
        );
      },
    );
  }

  String _rangeLabel(_TimeRange r) {
    switch (r) {
      case _TimeRange.d1:
        return '1D';
      case _TimeRange.w1:
        return '1W';
      case _TimeRange.m1:
        return '1M';
      case _TimeRange.m3:
        return '3M';
      case _TimeRange.all:
        return 'All';
    }
  }
}

// ─────────────────────────────────────────
// Asset Row
// ─────────────────────────────────────────
class _AssetRow extends StatelessWidget {
  final Item item;
  final double? currentPrice;
  final double? changePercent;

  const _AssetRow({
    required this.item,
    required this.currentPrice,
    required this.changePercent,
  });

  String get _displayName {
    final mhn = item.marketHashName ?? item.name;
    return mhn.replaceAll(RegExp(r'\s*\([^)]+\)$'), '').trim();
  }

  String? get _wear {
    final mhn = item.marketHashName ?? '';
    final match = RegExp(r'\(([^)]+)\)$').firstMatch(mhn);
    return match?.group(1);
  }

  bool get _isStatTrak => item.name.contains('StatTrak');

  @override
  Widget build(BuildContext context) {
    final isPositive = (changePercent ?? 0) >= 0;
    final changeColor = changePercent == null
        ? _textDim
        : (isPositive ? _green : _red);
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
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: item.image != null
                ? Image.network(
                    proxyImageUrl(item.image),
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, _) => _fallback,
                  )
                : _fallback,
          ),

          const SizedBox(width: 14),

          // Name + Wear + StatTrak
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
                const SizedBox(height: 3),
                Text(
                  _isStatTrak
                      ? 'StatTrak™${wear != null ? ' · $wear' : ''}'
                      : wear ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _isStatTrak
                        ? const Color(0xFFCF6A32)
                        : _textDim,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Price + Change %
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currentPrice != null
                    ? '\$${currentPrice!.toStringAsFixed(2)}'
                    : '—',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                changePercent != null
                    ? '${isPositive ? '+' : ''}${changePercent!.toStringAsFixed(1)}%'
                    : '—',
                style: TextStyle(
                  color: changeColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget get _fallback => Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF0A1A0A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.image_not_supported_outlined,
            color: _textDim, size: 24),
      );
}
