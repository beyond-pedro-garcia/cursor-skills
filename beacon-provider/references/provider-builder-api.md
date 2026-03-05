# Provider Builder API — `p` Reference

All providers import `{ defineProvider, p }` from `./config/define.provider.js`.

The `p` object exposes a fluent builder (chainable API). Each provider action (`captureSearchResult`, etc.) is an **array of chains** — each chain is a sequence of `p.*` calls that defines a trigger + extraction + push pipeline.

```javascript
import { defineProvider, p } from './config/define.provider.js';

export const myProvider = defineProvider(() => ({
  captureSearchResult: [
    p
      .trigger(...)       // 1. When to fire
      .extract(...)       // 2. What data to get
      .transform(...)     // 3. Process/clean
      .push(...)          // 4. Send event
  ],
}));

export const main = () => myProvider.main();
```

---

## Triggers — When to Fire

### URL / Navigation

```javascript
p.pathname(url => url.includes('/search'))
// Fires when the current URL matches the predicate.
// Re-evaluates on URL changes (SPA-safe).

p.urlChange()
// Fires on any SPA navigation (history.pushState / replaceState).
// Combine with .filter() to match specific transitions:
p.urlChange()
  .filter(({ lastUrl, nextUrl }) => nextUrl.includes('/confirmation'))
```

### Element Presence

```javascript
p.el('.search-results')
// Waits for a CSS selector to appear in the DOM before proceeding.
// Optional second arg is a fallback selector:
p.el('.results-grid', '.property-list')
```

### Mutations

```javascript
p.mutation(checkFn, options)
// Watches DOM for mutations. checkFn receives the mutated node.
// Fires when checkFn returns true.
```

### Network Requests

```javascript
p.fetchComplete(url => url.includes('/api/pricing'))
// Fires when a fetch() call to a matching URL completes.
// The resolved response body is passed downstream.

p.ajaxComplete(url => url.includes('/search'))
// Same but for XMLHttpRequest (legacy AJAX).
```

### Conditions & Timing

```javascript
p.waitFor(fn, timeoutMs)
// Polls fn() until it returns truthy, then proceeds.
// Useful for async framework state.

p.filter(fn)
// Conditional gate — if fn returns false, the chain stops.
// fn receives current context object.
```

---

## Data Extraction

### From the URL

```javascript
p.query()
// Parses current URL's query string into an object.
// e.g. ?checkin=2024-01-01&checkout=2024-01-07&guests=2
// → { checkin: '2024-01-01', checkout: '2024-01-07', guests: '2' }

p.query(({ resource }) => resource)
// When used after fetchComplete, parses the request URL instead.
```

### From the DOM

```javascript
p.elText({ checkin: '.checkin-date', checkout: '.checkout-date' })
// Extracts innerText of each selector into a keyed object.

p.elVal({ bedrooms: 'select#bedrooms', checkin: 'input[name=checkin]' })
// Extracts .value from form inputs.

p.elAttr({ listingId: ['[data-listing-id]', 'data-listing-id'] })
// Extracts an attribute from an element: [selector, attribute].

p.elCount({ resultCount: '.property-card' })
// Counts elements matching the selector.

p.dataset({ listingId: '.property-card' })
// Reads data-* attributes from element's dataset.

p.parseTable('.pricing-table')
// Parses an HTML table into an array of objects.
```

### From JavaScript State

```javascript
p.fn(() => {
  // Arbitrary JS — return an object to merge into context.
  return { listingId: window.PROPERTY_DATA?.id };
})

p.async(async () => {
  // Async variant — can await things.
  const data = await window.somePromise;
  return { total: data.price };
})

p.dataLayer('purchase', eventData => ({
  // Extracts from window.dataLayer (Google Analytics / GTM).
  // eventData is the matching dataLayer event object.
  revenue: eventData.ecommerce.purchase.revenue,
}))

p.vue({ selector: '#app', mapFn: vm => ({ listingId: vm.listing.id }) })
// Accesses the Vue instance on a selector.

p.nuxt({ mapFn: store => ({ checkin: store.search.checkin }) })
// Accesses Nuxt's window.$nuxt store.

p.nextjs({ mapFn: router => ({ listingId: router.query.id }) })
// Accesses Next.js's window.__NEXT_DATA__ and router.

p.linkingData()
// Parses <script type="application/ld+json"> structured data.

p.localStorageVal({ keyMap: { checkin: 'search_checkin' } })
// Reads values from localStorage.

p.json({ source: () => window.SEARCH_RESULTS })
// Parses a JS value (object/string) into context.
```

---

## Transformation

```javascript
p.parseMap({
  checkin:   p.parse.date('mm/dd/yyyy'),
  checkout:  p.parse.date('mm/dd/yyyy'),
  total:     p.parse.money(),
  bedrooms:  p.parse.int(),
  success:   p.parse.bool(),
})
// Applies parse functions to specific fields in the context object.
// Only transforms keys that exist; leaves others untouched.

p.chain(otherChain)
// Inlines another p.Builder chain — useful for reusing extraction logic.

p.debug('label')
// Logs current context to console — useful during development.
```

### Parse Helpers

```javascript
p.parse.int()           // '3 bedrooms' → 3
p.parse.money()         // '$1,234.56' or '1234.56 USD' → 1234.56
p.parse.date('format')  // Many formats: 'mm/dd/yyyy', 'yyyy-mm-dd', 'mmm d, yyyy', etc.
p.parse.bool()          // 'true'/'yes'/'1' → true
p.parse.string()        // Coerces to string
p.parse.amenity(map)    // Maps amenity names to a canonical list

// Direct use:
p.parse('$1,234').money()
p.parse('12/25/2024').date('mm/dd/yyyy')
```

---

## Pushing Events

```javascript
p.push(p.events.searchResult, context => ({
  // Map context fields to event schema fields.
  // See event-schemas.md for all required/optional fields.
  checkin:      context.checkin,
  checkout:     context.checkout,
  result_count: context.resultCount,
  bedrooms:     [context.bedrooms, null],  // [min, max] — use null if no max
}))

// All event types:
p.events.searchResult
p.events.propertyPageview
p.events.quote         // also: p.events.quoteResult
p.events.conversion
```

### HTML Upload (for debugging complex sites)

```javascript
p.htmlUpload()
// Captures full page HTML + localStorage + sessionStorage.
// Use on conversion pages where you need to debug.
// Strips SVGs, base64 images, style tags to keep size manageable.
// Always chain BEFORE .push() on conversions.
```

---

## Multiple Triggers for the Same Action

Provide an array of chains when the same event can be triggered multiple ways:

```javascript
captureSearchResult: [
  // Trigger 1: on page load if already on search page
  p.pathname(url => url.includes('/search'))
    .el('.results')
    .query()
    .push(p.events.searchResult, mapFn),

  // Trigger 2: when filters change via AJAX
  p.ajaxComplete(url => url.includes('/search'))
    .query(({ resource }) => resource)
    .push(p.events.searchResult, mapFn),
],
```

---

## Reusable Chains

Extract shared logic into a variable and `.chain()` it:

```javascript
const extractSearch = p
  .query()
  .elVal({ bedrooms: 'select#bedrooms' })
  .parseMap({ bedrooms: p.parse.int(), checkin: p.parse.date('yyyy-mm-dd') })
  .push(p.events.searchResult, ctx => ({ ...ctx }));

captureSearchResult: [
  p.pathname(url => url.includes('/search')).chain(extractSearch),
  p.fetchComplete(url => url.includes('/results')).chain(extractSearch),
],
```

---

## Multi-Site / Resolve Install

When one domain uses different providers depending on which booking engine is active:

```javascript
export const main = () => {
  myProvider.resolveInstall = (SITES) => {
    // Return the SITE config entry to use, or null to skip.
    if (window.BOOKING_ENGINE === 'v2') return SITES.find(s => s.provider === 'engine-v2');
    return SITES.find(s => s.provider === 'engine-v1');
  };
  return myProvider.main();
};
```
