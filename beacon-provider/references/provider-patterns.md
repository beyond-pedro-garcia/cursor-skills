# Provider Implementation Patterns

Real patterns drawn from existing Beacon providers. Match the website's
characteristics to the most fitting pattern before writing code.

---

## Pattern 1 — URL + DOM Scraping (Multi-Page App)

**When to use:** The URL changes on every navigation step (search page, property
page, booking page are distinct URLs). Content is server-rendered or
React/Vue-rendered but already in the DOM on load.

**How to detect:** Navigate the site — observe the address bar changing. Check
DevTools Elements for static HTML content.

**Example (villas365.js):**

```javascript
export const villas365Provider = defineProvider(() => ({
  captureSearchResult: [
    p
      .pathname(url => url.includes('/search'))
      .el('.search-results-count')
      .query()
      .elText({ resultCount: '.results-count span' })
      .elVal({ bedrooms: 'select[name=bedrooms]' })
      .parseMap({
        checkin:      p.parse.date('mm/dd/yyyy'),
        checkout:     p.parse.date('mm/dd/yyyy'),
        bedrooms:     p.parse.int(),
        resultCount:  p.parse.int(),
      })
      .push(p.events.searchResult, ctx => ({
        checkin:      ctx.checkin,
        checkout:     ctx.checkout,
        bedrooms:     [ctx.bedrooms, null],
        result_count: ctx.resultCount,
      })),
  ],

  capturePropertyPageview: [
    p
      .pathname(url => /\/property\/[\w-]+/.test(url))
      .el('[data-listing-id]')
      .elAttr({ listingId: ['[data-listing-id]', 'data-listing-id'] })
      .elText({ listingName: 'h1.property-title' })
      .push(p.events.propertyPageview, ctx => ({
        listing_id:   ctx.listingId,
        listing_name: ctx.listingName,
      })),
  ],
}));
```

---

## Pattern 2 — SPA with URL Change Detection

**When to use:** Single-page app where navigation happens without full page
reloads (React Router, Vue Router, Next.js). URL changes but no traditional
page load occurs.

**How to detect:** Click through the site — URL updates but browser doesn't
reload. Look for `history.pushState` in DevTools Performance tab.

**Example (happy-rentals.js — reusable chain variant):**

```javascript
// Define reusable extraction logic once
const captureSearch = p
  .el('.search-results')
  .query()
  .elText({ resultCount: '.result-count' })
  .parseMap({
    checkin:     p.parse.date('yyyy-mm-dd'),
    checkout:    p.parse.date('yyyy-mm-dd'),
    resultCount: p.parse.int(),
  })
  .push(p.events.searchResult, ctx => ({
    checkin:      ctx.checkin,
    checkout:     ctx.checkout,
    result_count: ctx.resultCount,
  }));

export const happyRentalsProvider = defineProvider(() => ({
  captureSearchResult: [
    // Trigger 1: initial page load on search route
    p.pathname(url => url.includes('/search')).chain(captureSearch),

    // Trigger 2: SPA navigation to search route
    p.urlChange()
      .filter(({ nextUrl }) => nextUrl.includes('/search'))
      .chain(captureSearch),

    // Trigger 3: filters changed via AJAX (no URL change)
    p.fetchComplete(url => url.includes('/api/search'))
      .chain(captureSearch),
  ],
}));
```

---

## Pattern 3 — AJAX / Fetch Interception

**When to use:** Pricing or search results arrive via network requests, not in
the initial HTML. Common for dynamic quote widgets and availability checks.

**How to detect:** Open DevTools Network tab → filter by Fetch/XHR → trigger
a search or get a quote → look for API calls returning JSON with pricing data.

**Example (fareharbor.js — fetch interception for quotes):**

```javascript
captureQuote: [
  p
    .fetchComplete(url => url.includes('/api/availability/'))
    .fn(({ response }) => {
      // `response` is the parsed JSON body from the intercepted fetch
      const item = response?.availability?.items?.[0];
      return {
        listingId:   response?.item?.pk,
        listingName: response?.item?.name,
        total:       item?.customer_type_rates?.[0]?.total_amount,
        checkin:     item?.start_at,
      };
    })
    .parseMap({
      total:   p.parse.money(),
      checkin: p.parse.date('yyyy-mm-ddThh:mm:ss'),
    })
    .push(p.events.quote, ctx => ({
      listing_id:    ctx.listingId,
      listing_name:  ctx.listingName,
      total:         ctx.total,
      checkin:       ctx.checkin,
      success:       ctx.total > 0,
    })),
],
```

---

## Pattern 4 — Framework State Access

**When to use:** The page uses a JavaScript framework (Vue, React/Next.js,
WordPress + WP Data, Angular) and the data you need is in the framework's
store rather than the DOM.

**How to detect:** Check browser console for `window.React`, `window.Vue`,
`window.__NEXT_DATA__`, `window.angular`, `window.wp`, etc.

**Example (lightmaker.js — WordPress WP Data store):**

```javascript
capturePropertyPageview: [
  p
    .el('[data-lmpm-property]')
    .fn(() => {
      const store = window.wp?.data?.select('lmpm/data');
      if (!store) return null;
      const property = store.activeProperty();
      return {
        listingId:   property?.id,
        listingName: property?.name,
      };
    })
    .filter(ctx => Boolean(ctx?.listingId))
    .push(p.events.propertyPageview, ctx => ({
      listing_id:   ctx.listingId,
      listing_name: ctx.listingName,
    })),
],

captureQuote: [
  p
    .fetchComplete(url => url.includes('/wp-json/lmpm/v1/quote'))
    .fn(({ response }) => ({
      total:     response?.total,
      lineItems: response?.line_items?.reduce((acc, item) => {
        acc[item.label] = item.amount;
        return acc;
      }, {}),
    }))
    .push(p.events.quote, ctx => ({
      listing_id: window.wp?.data?.select('lmpm/data')?.activeProperty()?.id,
      total:      ctx.total,
      line_items: ctx.lineItems,
      success:    ctx.total > 0,
    })),
],
```

**Example (Next.js via `__NEXT_DATA__`):**

```javascript
p
  .fn(() => {
    const data = window.__NEXT_DATA__?.props?.pageProps;
    return {
      listingId:   data?.listing?.id,
      listingName: data?.listing?.name,
    };
  })
```

**Example (Vue instance):**

```javascript
p.vue({
  selector: '#app',
  mapFn: vm => ({
    listingId:   vm.$store?.state?.listing?.id,
    listingName: vm.$store?.state?.listing?.name,
  }),
})
```

---

## Pattern 5 — Pure DOM Observation (No URL Change, No AJAX)

**When to use:** Everything happens on one URL with no navigation and no
detectable network requests. The UI updates purely through DOM manipulation.
Most challenging pattern.

**How to detect:** URL never changes. Network tab shows no relevant API calls.
But the page clearly updates (results appear, prices show) — the framework is
rendering everything client-side from already-loaded data.

**Strategies:**

```javascript
// Watch for a specific element to appear
p
  .mutation(node => node.matches?.('.results-container'), { subtree: true })
  .elText({ resultCount: '.result-count' })
  .push(p.events.searchResult, ctx => ({ result_count: ctx.resultCount }))

// Wait for a condition to become true
p
  .waitFor(() => document.querySelector('.price-total')?.innerText?.length > 0, 5000)
  .elText({ total: '.price-total' })
  .parseMap({ total: p.parse.money() })
  .push(p.events.quote, ctx => ({ total: ctx.total, success: true }))

// Poll a global variable that gets populated by framework
p
  .async(async () => {
    let attempts = 0;
    while (!window.SEARCH_STATE?.results && attempts < 20) {
      await new Promise(r => setTimeout(r, 250));
      attempts++;
    }
    const state = window.SEARCH_STATE;
    return { resultCount: state?.results?.length };
  })
  .push(p.events.searchResult, ctx => ({ result_count: ctx.resultCount }))
```

---

## Pattern 6 — DataLayer / GTM Integration

**When to use:** The site pushes events to `window.dataLayer` (Google Tag Manager
or GA4). This is common on modern e-commerce-style booking sites.

**How to detect:** In console: `window.dataLayer` — look for purchase/checkout
events. Network tab: look for requests to `google-analytics.com` or `gtm.js`.

**Example (fareharbor.js — conversion via dataLayer):**

```javascript
captureConversion: [
  p
    .dataLayer('purchase', eventData => ({
      reservationId: eventData?.ecommerce?.purchase?.transaction_id,
      total:         eventData?.ecommerce?.purchase?.revenue,
      currency:      eventData?.ecommerce?.purchase?.currency_code,
      listingId:     eventData?.ecommerce?.purchase?.products?.[0]?.id,
      listingName:   eventData?.ecommerce?.purchase?.products?.[0]?.name,
    }))
    .parseMap({ total: p.parse.money() })
    .push(p.events.conversion, ctx => ({
      listing_id:     ctx.listingId,
      listing_name:   ctx.listingName,
      reservation_id: ctx.reservationId,
      total:          ctx.total,
      currency:       ctx.currency,
    })),
],
```

---

## Conversion Best Practices

Conversions are the highest-value event. Always:

1. **Upload HTML first** for debugging capability:
```javascript
captureConversion: [
  p
    .pathname(url => url.includes('/confirmation'))
    .htmlUpload()   // ← always include on conversions
    .elText({ reservationId: '.confirmation-number' })
    .push(p.events.conversion, ctx => ({ ... }))
]
```

2. **Use the confirmation/thank-you page URL** as the trigger — not the
   checkout submit button — to avoid double-firing.

3. **Handle the case where the user refreshes** the confirmation page — your
   trigger should be idempotent.

---

## Investigating an Unknown Site — Step by Step

1. **Open the site** in a browser with DevTools open
2. **Network tab** — clear, then navigate through the funnel. Note any API
   calls that return search results or pricing JSON
3. **Console** — check `window.React`, `window.Vue`, `window.angular`,
   `window.wp`, `window.__NEXT_DATA__`, `window.dataLayer`
4. **Elements tab** — inspect key areas: search results count, property cards,
   price totals, confirmation numbers. Find stable CSS selectors
5. **Sources tab** — look at loaded scripts for framework/engine clues
6. **Check `<meta>` tags and script `src` attributes** — often reveal the
   booking engine (e.g. `lodgify.com`, `hostaway.com`, `lmpm.com`)
7. **Try the URL pattern test** — does adding `?checkin=2024-01-01` to the
   URL pre-fill the search?

---

## File Structure of a Complete Provider

```javascript
// js/src/providers/my-engine.js

import { defineProvider, p } from './config/define.provider.js';

// Optional: helper functions for repeated extraction logic
const getListingId = () => document.querySelector('[data-id]')?.dataset?.id;

// Optional: reusable chains
const parseQuote = p
  .fetchComplete(url => url.includes('/api/quote'))
  .fn(({ response }) => ({ total: response.total }))
  .push(p.events.quote, ctx => ({ total: ctx.total, success: true }));

export const myEngineProvider = defineProvider(() => ({
  captureSearchResult: [ /* chains */ ],
  capturePropertyPageview: [ /* chains */ ],
  captureQuote: [ /* chains */ ],
  captureConversion: [ /* chains */ ],
}));

export const main = () => {
  return myEngineProvider.main();
};
```
