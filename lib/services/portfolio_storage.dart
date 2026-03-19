import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart' show Item, buildMarketHashName;

/// Ein gespeicherter Wertpunkt für den Graph
class ValueSnapshot {
  final DateTime timestamp;
  final double totalValue;

  ValueSnapshot({required this.timestamp, required this.totalValue});
}

/// Firestore-Persistierung des Portfolio-Zustands.
///
/// Struktur:
///   steamProfiles/{steamId}            → Profil + initialPrices
///   portfolioHistory/{steamId}/snapshots/{YYYY-MM-DD}  → täglicher Snapshot
class PortfolioStorage {
  static final _db = FirebaseFirestore.instance;

  // ─── Steam-Profil (Items für den Cron-Job) ───────────────────────────────

  /// Speichert das Steam-Profil inkl. Items in Firestore (für den Cron-Job).
  static Future<void> saveSteamProfile(
    String steamId,
    List<Item> items,
  ) async {
    await _db.collection('steamProfiles').doc(steamId).set({
      'steamId': steamId,
      'items': items
          .map((item) => {
                'marketHashName': buildMarketHashName(item),
                'name': item.name,
                'image': item.image,
                'amount': item.amount,
                'rarityColor': item.rarityColor,
                'rarityName': item.rarityName,
              })
          .toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─── Initial-Snapshot ────────────────────────────────────────────────────

  /// Speichert die initialen Item-Preise, sofern noch keiner vorhanden.
  /// Gibt true zurück wenn erstmalig gespeichert.
  static Future<bool> saveInitialIfAbsent(
    String steamId,
    Map<String, double> prices,
  ) async {
    final ref = _db.collection('steamProfiles').doc(steamId);
    final doc = await ref.get();

    if (doc.exists && (doc.data()?['initialPrices'] as Map?)?.isNotEmpty == true) {
      return false;
    }

    await ref.set({
      'initialPrices': prices,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return true;
  }

  /// Lädt die initialen Item-Preise aus Firestore.
  static Future<Map<String, double>?> loadInitialPrices(String steamId) async {
    try {
      final doc =
          await _db.collection('steamProfiles').doc(steamId).get();
      if (!doc.exists) return null;
      final raw = doc.data()?['initialPrices'] as Map<String, dynamic>?;
      if (raw == null || raw.isEmpty) return null;
      return raw.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (_) {
      return null;
    }
  }

  // ─── Wert-History für den Graph ──────────────────────────────────────────

  /// Speichert einen Tages-Snapshot (idempotent, überschreibt gleichen Tag).
  static Future<void> appendValueHistory(
    String steamId,
    double totalValue,
  ) async {
    if (totalValue <= 0) return;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await _db
        .collection('portfolioHistory')
        .doc(steamId)
        .collection('snapshots')
        .doc(today)
        .set({
      'timestamp': FieldValue.serverTimestamp(),
      'totalValue': totalValue,
    });
  }

  /// Lädt alle gespeicherten Wert-Snapshots chronologisch.
  static Future<List<ValueSnapshot>> loadValueHistory(String steamId) async {
    try {
      final snap = await _db
          .collection('portfolioHistory')
          .doc(steamId)
          .collection('snapshots')
          .orderBy('timestamp')
          .get();

      return snap.docs.map((doc) {
        final data = doc.data();
        final ts = data['timestamp'] as Timestamp?;
        return ValueSnapshot(
          timestamp: ts?.toDate() ?? DateTime.now(),
          totalValue: (data['totalValue'] as num).toDouble(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Lädt den letzten gespeicherten Snapshot inkl. Itempreise (vom Cron-Job).
  static Future<({double totalValue, Map<String, double> itemPrices})?> loadLatestItemSnapshot(
    String steamId,
  ) async {
    try {
      final snap = await _db
          .collection('portfolioHistory')
          .doc(steamId)
          .collection('snapshots')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      final data = snap.docs.first.data();
      final totalValue = (data['totalValue'] as num?)?.toDouble() ?? 0;
      final rawPrices = data['itemPrices'] as Map<String, dynamic>?;
      final itemPrices = rawPrices?.map((k, v) => MapEntry(k, (v as num).toDouble())) ?? {};
      return (totalValue: totalValue, itemPrices: itemPrices);
    } catch (_) {
      return null;
    }
  }

  /// Löscht das Profil (beim Inventar-Reset).
  static Future<void> clearProfile(String steamId) async {
    await _db.collection('steamProfiles').doc(steamId).delete();
  }

  // ─── UID ↔ Steam-ID Verknüpfung ─────────────────────────────────────────

  /// Verknüpft die Firebase Auth UID mit einer Steam-ID.
  static Future<void> linkUidToSteamId(String uid, String steamId) async {
    await _db.collection('userProfiles').doc(uid).set({
      'steamId': steamId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Gibt die Steam-ID zurück die mit dieser UID verknüpft ist, oder null.
  static Future<String?> getSteamIdForUid(String uid) async {
    try {
      final doc = await _db.collection('userProfiles').doc(uid).get();
      return doc.data()?['steamId'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Lädt die gespeicherten Inventar-Items aus Firestore.
  static Future<List<Item>?> loadItems(String steamId) async {
    try {
      final doc = await _db.collection('steamProfiles').doc(steamId).get();
      if (!doc.exists) return null;
      final rawItems = doc.data()?['items'] as List<dynamic>?;
      if (rawItems == null || rawItems.isEmpty) return null;
      return rawItems.map((raw) {
        final m = raw as Map<String, dynamic>;
        return Item(
          id: m['marketHashName'] as String? ?? m['name'] as String? ?? '',
          name: m['name'] as String? ?? '',
          typeKey: 'skin',
          image: m['image'] as String?,
          marketHashName: m['marketHashName'] as String?,
          amount: (m['amount'] as num?)?.toInt() ?? 1,
          rarityColor: m['rarityColor'] as String?,
          rarityName: m['rarityName'] as String?,
        );
      }).toList();
    } catch (_) {
      return null;
    }
  }
}
