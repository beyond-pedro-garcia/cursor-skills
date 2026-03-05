# Beacon Event Schemas

All field values should be the correct type after parsing. Use `p.parseMap()` to transform raw DOM/URL strings before pushing.

---

## `searchResult`

Fired when a user performs a property search and results are visible.

```javascript
p.push(p.events.searchResult, ctx => ({
  // Dates — ISO 8601 strings (YYYY-MM-DD). null if not selected.
  checkin:           ctx.checkin,          // string | null
  checkout:          ctx.checkout,         // string | null

  // Flex search — number of flexible days. null if not flex.
  checkin_flex:      null,                 // number | null
  checkout_flex:     null,                 // number | null

  // Guests — [min, max]. Use null for max if there's no upper bound.
  guests_adults:     [ctx.adults, null],   // [number, number|null] | null
  guests_children:   [ctx.children, null], // [number, number|null] | null

  // Rooms — [min, max]. null if not filtered.
  bedrooms:          [ctx.bedrooms, null], // [number, number|null] | null
  bathrooms:         [ctx.bathrooms, null],

  // Price range — numbers (not strings). null if not filtered.
  price:             [ctx.minPrice, ctx.maxPrice], // [number, number] | null

  // Result count — integer. null if not determinable.
  result_count:      ctx.resultCount,      // number | null

  // Arrays of strings. Empty array [] if none, not null.
  amenities:         ctx.amenities ?? [],  // string[]
  property_types:    ctx.propertyTypes ?? [], // string[]
  locations:         ctx.locations ?? [],  // string[]
}))
```

---

## `propertyPageview`

Fired when a user lands on a specific property detail page.

```javascript
p.push(p.events.propertyPageview, ctx => ({
  // Required: at least one identifier.
  listing_id:    ctx.listingId,     // string | number
  listing_name:  ctx.listingName,   // string | null

  // Pre-filled dates from search context (if available).
  checkin:       ctx.checkin,       // string | null
  checkout:      ctx.checkout,      // string | null

  // Guests
  guests_adults:   ctx.adults,      // number | null
  guests_children: ctx.children,    // number | null
}))
```

---

## `quote` / `quoteResult`

Fired when a price quote is shown to the user (after they enter dates/guests for a specific property).

```javascript
p.push(p.events.quote, ctx => ({
  // Property
  listing_id:    ctx.listingId,     // string | number — required
  listing_name:  ctx.listingName,   // string | null

  // Stay
  checkin:       ctx.checkin,       // string — required
  checkout:      ctx.checkout,      // string — required
  guests_adults: ctx.adults,        // number | null
  guests_children: ctx.children,    // number | null

  // Pricing — numbers, not strings.
  total:         ctx.total,         // number — required (0 if unavailable)
  currency:      ctx.currency,      // ISO 4217 string e.g. 'USD', 'EUR' | null

  // Promo
  promo_code:    ctx.promoCode,     // string | null

  // Line items — object with string keys and number values.
  // e.g. { 'Rent': 1200.00, 'Cleaning Fee': 150.00, 'Taxes': 180.00 }
  line_items:    ctx.lineItems,     // object | null

  // Payment schedule — object with date keys and amount values.
  // e.g. { '2024-01-01': 500.00, '2024-01-15': 1030.00 }
  payments:      ctx.payments,      // object | null

  // State
  error_message: ctx.errorMessage,  // string | null (if pricing failed)
  success:       ctx.success,       // boolean — true if quote was successful
}))
```

---

## `conversion`

Fired on the booking confirmation page after a successful booking.

```javascript
p.push(p.events.conversion, ctx => ({
  // Property
  listing_id:     ctx.listingId,    // string | number — required
  listing_name:   ctx.listingName,  // string | null

  // Reservation
  reservation_id: ctx.reservationId, // string — the booking confirmation number

  // Stay
  checkin:        ctx.checkin,      // string — required
  checkout:       ctx.checkout,     // string — required
  guests_adults:  ctx.adults,       // number | null
  guests_children: ctx.children,    // number | null

  // Pricing
  total:          ctx.total,        // number — required
  currency:       ctx.currency,     // string | null
  promo_code:     ctx.promoCode,    // string | null

  // Line items and payments — same structure as quote
  line_items:     ctx.lineItems,    // object | null
  payments:       ctx.payments,     // object | null
}))
```

---

## Notes on Field Values

- **Dates:** Always `YYYY-MM-DD` strings after parsing. Use `p.parse.date('input-format')`.
- **Money:** Always plain numbers (no currency symbols, no commas). Use `p.parse.money()`.
- **Integers:** Always numbers (not strings). Use `p.parse.int()`.
- **Bedroom/bathroom ranges:** Always `[min, max]` arrays. If only a minimum is known, use `[min, null]`.
- **Null vs omit:** Prefer `null` over omitting a field entirely so the schema is explicit.
- **Arrays:** Use empty arrays `[]` not `null` for amenities/property_types/locations when empty.
