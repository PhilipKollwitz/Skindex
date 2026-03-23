/**
 * Cloud Functions: Steam-Preis, Skinport-Preis, Image-Proxy
 */

const { setGlobalOptions } = require("firebase-functions/v2/options");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
const axios = require("axios");
const { initializeApp, getApps } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");

if (getApps().length === 0) initializeApp();

const steamApiKey = defineSecret("STEAM_API_KEY");

const SKINPORT_CACHE_MS = 5 * 60 * 1000; // 5 Minuten
const skinportCache = {};
const skinportFetching = {}; // currency -> in-flight Promise (dedup)

/**
 * Fetches the full Skinport items list for a given currency.
 * Deduplicates concurrent requests: if a fetch is already in-flight,
 * all callers await the same Promise instead of making separate API calls.
 */
async function getSkinportItems(currency) {
  const now = Date.now();
  const cached = skinportCache[currency];
  if (cached && now - cached.ts < SKINPORT_CACHE_MS) {
    return cached.items;
  }

  // Already fetching? Wait for the same promise.
  if (skinportFetching[currency]) {
    return skinportFetching[currency];
  }

  // Start new fetch and store the promise so concurrent callers share it.
  skinportFetching[currency] = (async () => {
    try {
      const params = new URLSearchParams({ app_id: "730", currency });
      const apiResp = await axios.get(
        `https://api.skinport.com/v1/items?${params.toString()}`,
        {
          timeout: 15000,
          headers: {
            "Accept-Encoding": "br, gzip, deflate",
            "User-Agent": "Mozilla/5.0 (compatible; Skindex/1.0)",
          },
          decompress: true,
        }
      );
      const items = Array.isArray(apiResp.data) ? apiResp.data : [];
      skinportCache[currency] = { ts: Date.now(), items };
      return items;
    } finally {
      delete skinportFetching[currency];
    }
  })();

  return skinportFetching[currency];
}

// Region anpassen, wenn du willst (z.B. europe-west1)
setGlobalOptions({
  region: "europe-west1",
  maxInstances: 10,
});

/**
 * Einfache CORS-Behandlung für Browser-Aufrufe (Flutter Web)
 */
function handleCors(req, res) {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "GET,OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    // Preflight-Request
    res.status(204).send("");
    return true;
  }
  return false;
}


/**
 * GET /proxyImage?url=...
 *
 * Holt ein Bild (Steam, steamstatic etc.) serverseitig
 * und liefert es mit korrekten Headers zurück (CORS-safe für Flutter Web).
 */
exports.proxyImage = onRequest(async (req, res) => {
  if (handleCors(req, res)) return;

  if (req.method !== "GET") {
    res.status(405).json({ error: "Use GET" });
    return;
  }

  const url = req.query.url;
  if (!url) {
    res.status(400).json({ error: "Missing url parameter" });
    return;
  }

  let parsed;
  try {
    parsed = new URL(url);
  } catch (e) {
    res.status(400).json({ error: "Invalid URL" });
    return;
  }

  // Sicherheits-Whitelist für Hosts
  const allowedHosts = new Set([
    "steamcommunity.com",
    "steamcommunity-a.akamaihd.net",
    "community.cloudflare.steamstatic.com",
    "community.akamai.steamstatic.com",
    "cdn.steamstatic.com",
  ]);

  if (!allowedHosts.has(parsed.hostname)) {
    res.status(400).json({ error: "Host not allowed" });
    return;
  }

  try {
    const response = await axios.get(url, {
      responseType: "arraybuffer",
      headers: {
        "User-Agent": "Mozilla/5.0 (compatible; Skindex/1.0)",
        Referer: "https://steamcommunity.com/",
        Accept: "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
      },
      timeout: 10000,
    });

    const contentType = response.headers["content-type"] || "image/png";
    res.set("Content-Type", contentType);
    res.set("Cache-Control", "public, max-age=86400");
    res.send(Buffer.from(response.data));
  } catch (err) {
    logger.error("Error proxying image", err);
    res.status(500).json({ error: String(err) });
  }
});

/**
 * GET /skinportPrice?market_hash_name=...&currency=EUR
 *
 * Nutzt die öffentliche Skinport-Items-API und filtert auf einen market_hash_name.
 * (Kein API-Key nötig für /v1/items.)
 */
exports.skinportPrice = onRequest(async (req, res) => {
  if (handleCors(req, res)) return;

  if (req.method !== "GET") {
    res.status(405).json({ error: "Use GET" });
    return;
  }

  try {
    const mh = req.query.market_hash_name;
    const currency = (req.query.currency || "EUR").toUpperCase();

    if (!mh) {
      res.status(400).json({ error: "market_hash_name required" });
      return;
    }

    const now = Date.now();
    let cacheEntry = skinportCache[currency];

    // Cache abgelaufen oder noch nicht vorhanden -> neu von Skinport holen
    if (!cacheEntry || now - cacheEntry.ts > SKINPORT_CACHE_MS) {
      const params = new URLSearchParams({
        app_id: "730",
        currency,
      });

      const apiUrl = `https://api.skinport.com/v1/items?${params.toString()}`;

      const apiResp = await axios.get(apiUrl, {
        timeout: 10000,
        headers: {
          "Accept-Encoding": "br, gzip, deflate",
          "User-Agent": "Mozilla/5.0 (compatible; Skindex/1.0)",
        },
        decompress: true,
      });
      const items = Array.isArray(apiResp.data) ? apiResp.data : [];

      cacheEntry = {
        ts: now,
        items,
      };
      skinportCache[currency] = cacheEntry;
    }

    const items = cacheEntry.items;
    const item = items.find((x) => x.market_hash_name === mh);

    if (!item) {
      res.status(404).json({ error: "Item not found on Skinport" });
      return;
    }

    res.json({
      market_hash_name: item.market_hash_name,
      currency: item.currency || currency,
      min_price: item.min_price,
      max_price: item.max_price,
      suggested_price: item.suggested_price,
      item_page: item.item_page,     // Direktlink zum Item
      market_page: item.market_page, // Optionaler Fallback
    });
  } catch (err) {
    console.error("skinportPrice error", err?.response?.data || err);
    res.status(500).json({ error: "skinportPrice internal error" });
  }
});
/**
 * Täglicher Cron-Job (06:00 UTC): Skinport-Preise für alle registrierten
 * Steam-Profile abrufen und als Portfolio-Snapshot in Firestore speichern.
 */
exports.dailyPortfolioSnapshot = onSchedule(
  { schedule: "0 6 * * *", region: "europe-west1", timeZone: "UTC" },
  async () => {
    const db = getFirestore();

    // 1. Alle Skinport-Preise auf einmal holen (Bulk-API, kein API-Key nötig)
    const priceMap = {};
    try {
      const response = await axios.get("https://api.skinport.com/v1/items", {
        params: { app_id: "730", currency: "EUR" },
        timeout: 30000,
        headers: {
          "Accept-Encoding": "br, gzip, deflate",
          "User-Agent": "Mozilla/5.0 (compatible; Skindex/1.0)",
        },
        decompress: true,
      });
      if (Array.isArray(response.data)) {
        for (const item of response.data) {
          if (item.market_hash_name && item.suggested_price != null) {
            priceMap[item.market_hash_name] = item.suggested_price;
          }
        }
      }
      logger.info(`Skinport: ${Object.keys(priceMap).length} Preise geladen.`);
    } catch (e) {
      logger.error("Skinport Bulk-Fetch fehlgeschlagen:", e.message);
      return;
    }

    // 2. Alle Steam-Profile aus Firestore laden
    const profiles = await db.collection("steamProfiles").get();
    if (profiles.empty) {
      logger.info("Keine Steam-Profile vorhanden.");
      return;
    }

    // 3. Für jedes Profil Gesamtwert berechnen + Snapshot speichern
    const today = new Date().toISOString().substring(0, 10); // YYYY-MM-DD
    const batch = db.batch();
    let count = 0;

    for (const doc of profiles.docs) {
      const { items = [] } = doc.data();
      const steamId = doc.id;
      let totalValue = 0;

      for (const item of items) {
        const price = priceMap[item.marketHashName];
        if (price != null) {
          totalValue += price * (item.amount || 1);
        }
      }

      if (totalValue > 0) {
        const ref = db
          .collection("portfolioHistory")
          .doc(steamId)
          .collection("snapshots")
          .doc(today);

        batch.set(ref, {
          timestamp: FieldValue.serverTimestamp(),
          totalValue,
        });
        count++;
      }
    }

    await batch.commit();
    logger.info(`Snapshots gespeichert für ${count}/${profiles.size} Profile.`);
  }
);

// ─── Icon-Cache: in-memory + Firestore persistent ───────────────────────────
const imageCache = {};

async function fetchSteamIconUrl(marketHashName) {
  // 1. In-memory cache (only positive hits — never cache null so retries happen)
  if (imageCache[marketHashName]) return imageCache[marketHashName];

  const db = getFirestore();
  const docKey = marketHashName.replace(/\//g, "_").replace(/[^a-zA-Z0-9_\-]/g, "x");
  const docRef = db.collection("iconCache").doc(docKey);

  // 2. Firestore cache (only trust non-null entries)
  try {
    const snap = await docRef.get();
    if (snap.exists) {
      const cached = snap.data().iconUrl;
      if (cached) {
        imageCache[marketHashName] = cached;
        return cached;
      }
    }
  } catch (_) { /* ignore */ }

  // 3. Steam Market search — fetch multiple results and find exact match
  try {
    const encoded = encodeURIComponent(marketHashName);
    const url =
      `https://steamcommunity.com/market/search/render/?appid=730&norender=1&count=10&search_descriptions=0&query=${encoded}`;
    const resp = await axios.get(url, {
      timeout: 8000,
      headers: {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept-Language": "en-US,en;q=0.9",
      },
    });
    const results = resp.data?.results;
    if (Array.isArray(results) && results.length > 0) {
      // Prefer exact name match, fall back to first result
      const match = results.find(
        (r) => r.hash_name === marketHashName || r.name === marketHashName
      ) || results[0];
      const iconHash = match?.asset_description?.icon_url;
      if (iconHash) {
        const full = `https://community.cloudflare.steamstatic.com/economy/image/${iconHash}/360fx360f`;
        imageCache[marketHashName] = full;
        docRef.set({ iconUrl: full, name: marketHashName }).catch(() => {});
        return full;
      }
    }
  } catch (_) { /* ignore — will retry next request */ }

  return null; // Do NOT cache null — allow retry on next request
}

/**
 * GET /skinportMarket?currency=EUR
 *
 * Gibt Deals (günstig vs. Empfehlung) + Trending-Items zurück,
 * angereichert mit Steam-CDN-Bild-URLs.
 * Nutzt denselben 5-min-Cache wie /skinportPrice.
 */
exports.skinportMarket = onRequest({ maxInstances: 1 }, async (req, res) => {
  if (handleCors(req, res)) return;
  if (req.method !== "GET") { res.status(405).json({ error: "Use GET" }); return; }

  const currency = (req.query.currency || "EUR").toUpperCase();

  let items;
  try {
    items = await getSkinportItems(currency);
  } catch (err) {
    logger.error("skinportMarket fetch error", err.message);
    res.status(500).json({ error: "Skinport fetch failed" });
    return;
  }

  // Deals: min_price deutlich unter suggested_price
  const rawDeals = items
    .filter((i) => i.min_price != null && i.suggested_price > 1 && i.quantity > 0)
    .map((i) => ({
      market_hash_name: i.market_hash_name,
      min_price: i.min_price,
      suggested_price: i.suggested_price,
      quantity: i.quantity,
      discount_pct: Math.round((1 - i.min_price / i.suggested_price) * 100),
      // Skinport may include "image" field (Steam CDN path) — use if available
      _skinportImage: i.image || i.icon || null,
      item_page: i.item_page || null,
      updated_at: i.updated_at || null,
    }))
    .filter((i) => i.discount_pct >= 5)
    .sort((a, b) => b.discount_pct - a.discount_pct)
    .slice(0, 25);

  // For items Skinport didn't provide an image for, look up via Steam + Firestore cache
  const needsIcon = rawDeals
    .filter((i) => !i._skinportImage && !imageCache[i.market_hash_name])
    .map((i) => i.market_hash_name);

  // Load Firestore/memory cache first (parallel — no rate limit)
  await Promise.allSettled(needsIcon.map((n) => fetchSteamIconUrl(n)));

  // Sequentially fetch remaining unknowns from Steam (rate-limit friendly)
  const stillMissing = needsIcon.filter((n) => !imageCache[n]);
  for (const n of stillMissing) {
    await fetchSteamIconUrl(n);
    await new Promise((r) => setTimeout(r, 200));
  }

  const deals = rawDeals.map((i) => {
    const { _skinportImage, ...rest } = i;
    const iconUrl = _skinportImage || imageCache[i.market_hash_name] || null;
    return { ...rest, icon_url: iconUrl };
  });

  res.json({
    deals,
    trending: [],
    fetched_at: Date.now(),
  });
});

/**
 * GET /skinportBulkPrices?hashes=AK-47%20|%20Redline,...&currency=EUR
 *
 * Gibt Preise für mehrere Items auf einmal zurück (1 API-Call statt N).
 * Nutzt denselben 5-min-Cache wie /skinportPrice.
 */
exports.skinportBulkPrices = onRequest({ maxInstances: 1 }, async (req, res) => {
  if (handleCors(req, res)) return;
  if (req.method !== "GET") { res.status(405).json({ error: "Use GET" }); return; }

  const currency = (req.query.currency || "EUR").toUpperCase();
  const hashesParam = req.query.hashes;
  if (!hashesParam) {
    res.status(400).json({ error: "hashes parameter required" });
    return;
  }
  const hashes = hashesParam.split(",").map((h) => h.trim()).filter(Boolean);

  let allItems;
  try {
    allItems = await getSkinportItems(currency);
  } catch (err) {
    logger.error("skinportBulkPrices fetch error", err.message);
    res.status(500).json({ error: "Skinport fetch failed" });
    return;
  }

  // Index aufbauen für O(1) Lookup
  const index = {};
  for (const item of allItems) {
    if (item.market_hash_name) index[item.market_hash_name] = item;
  }

  const result = {};
  for (const hash of hashes) {
    const item = index[hash];
    if (item) {
      result[hash] = {
        currency: item.currency || currency,
        min_price: item.min_price ?? null,
        max_price: item.max_price ?? null,
        suggested_price: item.suggested_price ?? null,
      };
    }
  }

  res.json(result);
});

/**
 * GET /resolveVanityUrl?vanityurl=CustomID
 *
 * Löst eine Steam Custom-URL (Vanity-URL) in eine SteamID64 auf.
 * Benötigt den Steam API Key (als Secret hinterlegt).
 */
exports.resolveVanityUrl = onRequest(
  { secrets: [steamApiKey] },
  async (req, res) => {
    if (handleCors(req, res)) return;
    if (req.method !== "GET") {
      res.status(405).json({ error: "Use GET" });
      return;
    }

    const vanityurl = req.query.vanityurl;
    if (!vanityurl) {
      res.status(400).json({ error: "vanityurl parameter required" });
      return;
    }

    try {
      const response = await axios.get(
        "https://api.steampowered.com/ISteamUser/ResolveVanityURL/v1/",
        {
          params: { key: steamApiKey.value(), vanityurl },
          timeout: 8000,
        }
      );

      const result = response.data?.response;
      if (result?.success === 1) {
        res.json({ steamId: result.steamid });
      } else {
        res.status(404).json({ error: "Custom-URL nicht gefunden." });
      }
    } catch (err) {
      logger.error("resolveVanityUrl error", err.message);
      res.status(500).json({ error: "Fehler beim Auflösen der Custom-URL." });
    }
  }
);

// Proxy für das CS2-Inventar (App 730, Context 2)
exports.steamInventory = onRequest(async (req, res) => {
  // CORS erlauben (für Flutter Web)
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  const steamId = req.query.steamId;
  const count = req.query.count || "2000";
  const startAssetId = req.query.start_assetid;

  if (!steamId) {
    res.status(400).json({ error: "steamId query parameter required" });
    return;
  }

  const baseUrl = `https://steamcommunity.com/inventory/${steamId}/730/2`;
  const params = new URLSearchParams({ l: "english", count });
  if (startAssetId) params.set("start_assetid", startAssetId);

  const url = `${baseUrl}?${params.toString()}`;

  try {
    const response = await axios.get(url, {
      headers: {
        "User-Agent": "Mozilla/5.0 Skindex/1.0",
        "Accept": "application/json,text/javascript,*/*;q=0.01",
        "Referer": "https://steamcommunity.com/",
      },
    });

    res.status(200).json(response.data);
  } catch (err) {
    console.error("steamInventory error:", err.response?.status, err.message);
    res.status(500).json({
      error: "inventory_fetch_failed",
      status: err.response?.status ?? null,
      message: err.message,
    });
  }
});
