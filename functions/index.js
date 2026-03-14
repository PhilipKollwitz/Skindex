/**
 * Cloud Functions: Steam-Preis, Skinport-Preis, Image-Proxy
 */

const { setGlobalOptions } = require("firebase-functions/v2/options");
const { onRequest } = require("firebase-functions/v2/https");
const logger = require("firebase-functions/logger");
const axios = require("axios");
const SKINPORT_CACHE_MS = 5 * 60 * 1000; // 5 Minuten
const skinportCache = {};

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
 * GET /steamPrice?market_hash_name=...&currency=3&country=DE
 *
 * Wrappt Steam /market/priceoverview/
 */
exports.steamPrice = onRequest(async (req, res) => {
  if (handleCors(req, res)) return;

  if (req.method !== "GET") {
    res.status(405).json({ error: "Use GET" });
    return;
  }

  const marketHashName = req.query.market_hash_name;
  if (!marketHashName) {
    res.status(400).json({ error: "Missing market_hash_name" });
    return;
  }

  const currency = req.query.currency || "3"; // 3 = EUR
  const country = req.query.country || "DE";

  try {
    const response = await axios.get(
      "https://steamcommunity.com/market/priceoverview/",
      {
        params: {
          appid: 730,
          currency,
          market_hash_name: marketHashName,
          country,
          language: "german",
        },
        headers: {
          "User-Agent":
            "Mozilla/5.0 (compatible; Skindex/1.0; +https://example.com)",
          Referer: "https://steamcommunity.com/market/",
          Accept: "application/json,text/javascript,*/*;q=0.01",
        },
        timeout: 10000,
      }
    );

    res.json(response.data);
  } catch (err) {
    logger.error("Error fetching Steam price", err);
    res.status(500).json({
      success: false,
      error: String(err),
    });
  }
});

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
        tradable: "1",
      });

      const apiUrl = `https://api.skinport.com/v1/items?${params.toString()}`;

      const apiResp = await axios.get(apiUrl, { timeout: 10000 });
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
