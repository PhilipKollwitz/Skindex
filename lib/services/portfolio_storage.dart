import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Ein gespeicherter Wertpunkt für den Graph
class ValueSnapshot {
  final DateTime timestamp;
  final double totalValue;

  ValueSnapshot({required this.timestamp, required this.totalValue});

  Map<String, dynamic> toJson() => {
        'ts': timestamp.millisecondsSinceEpoch,
        'v': totalValue,
      };

  factory ValueSnapshot.fromJson(Map<String, dynamic> j) => ValueSnapshot(
        timestamp: DateTime.fromMillisecondsSinceEpoch(j['ts'] as int),
        totalValue: (j['v'] as num).toDouble(),
      );
}

/// Persistierung des Portfolio-Zustands mit SharedPreferences
class PortfolioStorage {
  static String _snapshotKey(String steamId) => 'portfolio_init_$steamId';
  static String _historyKey(String steamId) => 'portfolio_history_$steamId';

  // ─── Initial-Snapshot (Preise beim ersten Einlesen) ─────────────────────

  /// Speichert die initialen Item-Preise, sofern noch kein Snapshot vorhanden.
  /// Gibt true zurück wenn gespeichert wurde (erster Aufruf), sonst false.
  static Future<bool> saveInitialIfAbsent(
    String steamId,
    Map<String, double> prices,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _snapshotKey(steamId);
    if (prefs.containsKey(key)) return false; // Bereits vorhanden
    final encoded = jsonEncode(prices.map((k, v) => MapEntry(k, v)));
    await prefs.setString(key, encoded);
    return true;
  }

  /// Lädt die initialen Item-Preise. Gibt null zurück wenn noch keiner vorhanden.
  static Future<Map<String, double>?> loadInitialPrices(
      String steamId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_snapshotKey(steamId));
    if (raw == null) return null;
    final Map<String, dynamic> decoded = jsonDecode(raw);
    return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  /// Löscht den Initial-Snapshot (z.B. beim Reset des Inventars).
  static Future<void> clearSnapshot(String steamId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_snapshotKey(steamId));
    await prefs.remove(_historyKey(steamId));
  }

  // ─── Wert-History für den Graph ─────────────────────────────────────────

  /// Fügt einen neuen Wertpunkt zur History hinzu.
  /// Doppelte Punkte im selben 30-Minuten-Fenster werden ignoriert.
  static Future<void> appendValueHistory(
      String steamId, double totalValue) async {
    if (totalValue <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final key = _historyKey(steamId);
    final history = await loadValueHistory(steamId);

    // Duplikat-Schutz: letzten Punkt nicht öfter als alle 30 min schreiben
    if (history.isNotEmpty) {
      final last = history.last;
      final diff = DateTime.now().difference(last.timestamp);
      if (diff.inMinutes < 30) {
        // Wert updaten statt neuen Punkt anlegen
        history[history.length - 1] =
            ValueSnapshot(timestamp: last.timestamp, totalValue: totalValue);
        await prefs.setString(
            key, jsonEncode(history.map((s) => s.toJson()).toList()));
        return;
      }
    }

    history.add(
        ValueSnapshot(timestamp: DateTime.now(), totalValue: totalValue));

    // Maximal 1000 Punkte behalten
    final trimmed =
        history.length > 1000 ? history.sublist(history.length - 1000) : history;
    await prefs.setString(
        key, jsonEncode(trimmed.map((s) => s.toJson()).toList()));
  }

  /// Lädt die gesamte Wert-History.
  static Future<List<ValueSnapshot>> loadValueHistory(String steamId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey(steamId));
    if (raw == null) return [];
    final List<dynamic> decoded = jsonDecode(raw);
    return decoded
        .map((e) => ValueSnapshot.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
