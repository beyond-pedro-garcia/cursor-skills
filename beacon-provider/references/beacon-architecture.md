# Beacon — Architecture Reference

## What Beacon Is

Beacon is a lightweight JavaScript widget installed on short-term rental (STR) booking websites. It sits invisibly on the page and tracks user activity through the booking funnel — searches, property views, price quotes, and conversions (bookings). Events are sent to a Beyond backend for analytics.

The project lives at `~/GitHub/beyondpricing/beacon`.

```
beacon/
├── js/        ← The client-side widget (this is where you work)
├── py/        ← Backend ingestion server and parse pipeline
└── ...
```

---

## How It Works End-to-End

```
Client website loads beacon script (from CDN)
       ↓
Script reads site-config.json → finds matching domain → loads provider
       ↓
Provider watches the page (DOM, URLs, AJAX, framework state)
       ↓
When a relevant event happens, provider extracts data and pushes an event
       ↓
Events are buffered in localStorage → batched → POST'd to /batch endpoint
       ↓
Backend validates, logs, parses into ClickHouse + PostgreSQL
```

---

## The `js/` Folder

```
js/
├── src/
│   ├── providers/
│   │   ├── config/
│   │   │   ├── define.provider.js     ← defineProvider() and p export
│   │   │   └── utils/
│   │   │       ├── provider.js        ← p.Builder base class (1472 lines)
│   │   │       └── parse.js
│   │   ├── base/                      ← Shared base providers (bluetent, hostaway, supercontrol)
│   │   └── *.js                       ← 130+ individual provider files
│   ├── generated/
│   │   └── site-config.json           ← Maps domains → providers (500+ entries)
│   └── utils/                         ← Shared utilities
├── scripts/
│   └── gen-provider.js                ← Template generator for new providers
├── dist/                              ← Build output (payload.{provider}.js)
├── package.json
└── rollup.config.js
```

### Key npm scripts (run from `js/`)

```bash
npm run gen-provider <name>   # Generate new provider template
npm run build                 # Production build (all providers → dist/)
npm start                     # Dev mode with watch
```

---

## `site-config.json` Schema

File: `js/src/generated/site-config.json`

Each entry maps a customer installation to a provider:

```json
{
  "installId": 466,          // Unique installation ID (can be any number for local testing)
  "clientId": 10,            // Customer ID in Beyond system (mock for local testing)
  "siteKey": "f489e3f76c509521",  // Security key (mock for local testing)
  "provider": "signal",      // MUST match the provider filename without .js
  "domain": "signal.beyondpricing.com"  // Exact domain of the website
}
```

Optional field for complex sites:
```json
{
  "slugMap": {
    "park-city-vacation-rentals/feature/house/": {
      "property_types": ["House"]
    }
  }
}
```

**For local testing**, everything except `domain` and `provider` can be mocked with fake values.

---

## Provider Lifecycle

1. Script detects domain → looks up `site-config.json`
2. Loads matching provider bundle from CDN
3. Provider's `main()` runs — sets up all watchers/triggers
4. When user interacts, provider captures data and calls `push()`
5. Events queue in localStorage → batch sent to server

---

## Backend Event Payload Structure

```json
{
  "meta": {
    "client_id": 123,
    "url": "https://example.com/search",
    "site_key": "abc123",
    "user_id": "...",
    "session_id": "...",
    "pageview_id": "...",
    "install_id": 466
  },
  "events": [
    {
      "action": "searchResult",
      "offset": 0,
      "payload": { /* event fields */ }
    }
  ]
}
```

---

## Website Investigation Checklist

When opening a new website URL, always check:

1. **Does the URL change when navigating?** (Multi-page app vs SPA)
2. **What framework powers it?** Check:
   - `window.React` or `window.__NEXT_DATA__` → Next.js/React
   - `window.Vue` or `window.__vue_app__` → Vue / Nuxt
   - `window.angular` → AngularJS
   - `window.wp` → WordPress
   - Response HTML for framework clues (generator meta tag, script srcs, class naming)
3. **Network requests:** Filter by Fetch/XHR — are there API calls for search/pricing?
4. **URL patterns:** Does the URL update on search? On property view?
5. **DOM structure:** What CSS selectors identify key elements (results count, listing IDs, dates)?
6. **Booking engine brand:** Look for recognizable engine names in scripts/network requests (Lightmaker, Bizcor, Fare Harbor, Hostaway, etc.)
