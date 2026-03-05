---
name: beacon-provider
description: >
  Use this skill for any work related to creating or extending Beacon providers
  — the client-side tracking scripts installed on short-term rental booking
  websites. Beacon is located at ~/GitHub/beyondpricing/beacon.

  Invoke when the user says things like:
  - "create a provider for [url]"
  - "new beacon provider for [website]"
  - "implement the captureSearchResult / captureQuote / capturePropertyPageview /
    captureConversion action"
  - "take a look at [url] and implement [action]"
  - "/beacon-provider"

  Works in two modes:
  MODE A — New Provider: analyse a website, generate the provider scaffold,
  add it to site-config, and implement the first requested action.
  MODE B — Implement Action: add or improve a specific action on an existing
  provider, guided by a live URL the user provides.
---

# Beacon Provider Skill

## Reference Material

Load all of these before doing any work — they contain everything you need to
understand the system, the API, and the patterns:

- `references/beacon-architecture.md` — system overview, folder structure,
  site-config schema, end-to-end event flow
- `references/provider-builder-api.md` — complete `p` builder API reference
- `references/event-schemas.md` — required and optional fields for every event
- `references/provider-patterns.md` — real implementation patterns with examples

The beacon project root is: `~/GitHub/beyondpricing/beacon`
All `npm` commands run from: `~/GitHub/beyondpricing/beacon/js`

---

## Subagent Strategy

This skill uses subagents to parallelize independent work and keep the browser
investigation isolated from file editing. Key rules:

- **Browser subagents** handle all live site investigation — they receive the
  URL and a focused investigation checklist as context (they have no
  conversation history, so all context must be passed explicitly).
- **Bash subagents** handle builds — they can run in the background while you
  do other work.
- **Explore subagents** handle reading the existing provider file and the
  site-config — can run in parallel with browser investigation in Mode B.
- **No nesting** — subagents cannot spawn their own subagents.

Concrete parallelism opportunities called out in each mode below.

---

## Mode Detection

Determine which mode applies before doing anything else.

**Mode A — New Provider** when:
- The user mentions a website that has no provider yet
- The user says "create", "new provider", or "generate a provider"
- There is no existing entry for the domain in `site-config.json`

**Mode B — Implement Action** when:
- A provider already exists for the website
- The user says "implement [action]", "take a look at [url] and implement..."
- The user says "reimplement", "update", "fix", or "improve" an existing action
- The user is iterating on an existing provider

If unclear, check `js/src/generated/site-config.json` for the domain and ask
if no entry exists.

---

## MODE A — New Provider

### A1. Investigate the website — via Browser subagent (foreground)

Delegate the full site investigation to a **Browser subagent**. Run it in
**foreground** so you have the findings before proceeding.

Pass the following context explicitly in the delegation prompt (the subagent
has no conversation history):

> "You are investigating a short-term rental booking website to help implement
> a Beacon tracking provider. Beacon captures search results, property
> pageviews, quotes, and conversions.
>
> Open [URL] and navigate through the full booking funnel: search for
> properties, open a property detail page, trigger a price quote, and observe
> the confirmation flow.
>
> Report back:
> 1. Framework / booking engine — check window.React, window.__NEXT_DATA__,
>    window.Vue, window.angular, window.wp, window.dataLayer in the console;
>    inspect meta generator tags, script src attributes, and CSS class naming
> 2. Navigation model — does the URL change on each step? Is it a SPA? Does
>    everything happen on one URL with no navigation?
> 3. Network requests — open the Network tab and note any Fetch/XHR calls that
>    return search results or pricing JSON (include the URL patterns)
> 4. DOM extraction points — CSS selectors or data attributes for: result count,
>    listing IDs, property names, date inputs, guest/bedroom filters,
>    price totals, confirmation/reservation numbers
> 5. Your recommended implementation pattern:
>    - Pattern 1: URL + DOM scraping (multi-page, server-rendered)
>    - Pattern 2: SPA + URL change detection
>    - Pattern 3: AJAX/fetch interception
>    - Pattern 4: Framework state access (Vue/React/WP store)
>    - Pattern 5: DOM observation / mutation (no URL change, no AJAX)
>    - Pattern 6: DataLayer / GTM
> 6. Any concerns or ambiguities"

Once the subagent returns, summarise its findings for the user — framework,
navigation model, chosen pattern, concerns — and confirm before proceeding.

### A2. Generate the provider scaffold

```bash
cd ~/GitHub/beyondpricing/beacon/js
npm run gen-provider <provider-name>
```

Name the provider after the booking engine or framework, not the specific
website (e.g. `my-engine`, not `bookbrokenbow`). This makes it reusable for
other sites running the same engine. Use lowercase kebab-case.

This creates: `js/src/providers/<provider-name>.js`

### A3. Add an entry to site-config.json

Open `js/src/generated/site-config.json` and add an entry for the website.
For local testing, all fields except `domain` and `provider` can be mocked:

```json
{
  "installId": 9999,
  "clientId": 9999,
  "siteKey": "localtestkey00000",
  "provider": "<provider-name>",
  "domain": "<exact domain without https://>"
}
```

Add it at the end of the array (before the closing `]`).

### A4. Build — via Bash subagent (foreground)

Delegate the build to a **Bash subagent** in **foreground**:

> "Run `cd ~/GitHub/beyondpricing/beacon/js && npm run build` and return the
> full output, including any errors or warnings."

Fix any build errors reported before proceeding.

### A5. Implement the first action

Implement the action the user requested. If no specific action was mentioned,
implement `captureSearchResult` first as it is the most immediately testable.

Follow the steps in **Mode B — Implement Action** from this point.

---

## MODE B — Implement Action

This mode handles iterative development. The user provides a URL showing the
state they want to capture (e.g. a page showing search results, a property
with a quote widget open, a booking confirmation).

### B1. Read the existing provider and investigate the URL — in parallel

Launch these two subagents **simultaneously**:

**Subagent 1 — Explore (foreground):** Read the existing provider and assess
the target action.

> "Read the file ~/GitHub/beyondpricing/beacon/js/src/providers/<provider-name>.js
> in full. Then report:
> 1. The complete current implementation of the `<action>` action (copy it
>    verbatim), or confirm it is empty/unimplemented
> 2. What triggers it uses, what data it extracts, and how it pushes the event
> 3. If it's broken or incomplete: your best guess at why (wrong selector,
>    outdated AJAX URL, missing field, wrong trigger condition)
> 4. What can be preserved vs what needs to change
> Also list the names of all other actions present so we know what must not
> be touched."

**Subagent 2 — Browser (foreground):** Investigate the specific page state
for this action.

Pass the action name, the URL, and a focused checklist (see B2 below for the
per-action checklists). Include this context:

> "You are investigating a short-term rental booking website to help implement
> the `<action>` action for a Beacon tracking provider. Beacon is a script
> that captures booking funnel events.
> Open [URL] and [paste the relevant checklist from B2]."

Synthesise both results before writing any code. Tell the user:
- What the current implementation does (or that it's empty)
- What you found on the live page
- Your implementation plan
- What will change vs what will be preserved

### B2. Per-action investigation checklists

Use the relevant checklist as the body of the Browser subagent prompt in B1.

Based on which action you are implementing, look for:

**`captureSearchResult`**
- How many results are shown? Where is the count in the DOM?
- What search filters are visible? (dates, bedrooms, guests, price range,
  amenities, property types, locations)
- Are filters in the URL query string or only in the DOM?
- Does the results page update dynamically via AJAX when filters change?
- CSS selectors for: result count element, date inputs, bedroom/guest selects

**`capturePropertyPageview`**
- What uniquely identifies this property? (data attribute, URL slug, JS global)
- Where is the property name in the DOM?
- Are checkin/checkout dates pre-filled from a prior search?
- CSS selectors for: property title, listing ID holder

**`captureQuote`**
- How does the user request a quote? (form submit, auto-update on date change)
- Is the price loaded via AJAX, or does the page reload?
- If AJAX: open Network tab, trigger a quote, find the request URL and response JSON
- If DOM: which elements show the total, line items, and payment schedule?
- Where is the listing ID at this point in the flow?

**`captureConversion`**
- What URL does the confirmation page have? (check for `/confirmation`,
  `/thank-you`, `/booking/done`, etc.)
- What elements show the reservation/confirmation number?
- Are dates, totals, and guest counts on this page?
- If you can't reach a real confirmation page: inspect DOM structure, look
  for confirmation number patterns, or ask the user to provide a screenshot

### B3. Choose the right implementation approach


Based on what you found, pick the most appropriate pattern from
`references/provider-patterns.md`. When multiple patterns could work:
- Prefer DOM scraping over AJAX interception when data is already in the DOM
- Prefer AJAX interception when timing is uncertain (data loads asynchronously)
- Always use `p.htmlUpload()` on conversion events

### B4. Implement the action

**Only touch the action you were asked to work on.** Leave every other action
(`captureSearchResult`, `capturePropertyPageview`, `captureQuote`,
`captureConversion`) exactly as it is — do not refactor, reformat, rename, or
"improve" them even if they look suboptimal. The only lines you may change are
those belonging to the specific action in scope.

Edit the provider file and implement the action.

Checklist:
- [ ] Correct trigger (URL pattern, element presence, AJAX hook, etc.)
- [ ] All extractable fields from the event schema are captured
- [ ] `parseMap` applied for dates (ISO output), money (number), integers
- [ ] Null-safe access for optional fields
- [ ] Multiple trigger chains if the event can fire from different conditions
- [ ] No hardcoded domain-specific values that would break on other sites
  using the same engine

### B5. Build and verify — via Bash subagent (background)

Once the file edits are done, launch a **Bash subagent in background** so the
build runs while you write the summary to the user:

> "Run `cd ~/GitHub/beyondpricing/beacon/js && npm run build` and return the
> full output including any errors."

If the subagent returns errors, fix them and rebuild. Then report to the user:
- What trigger(s) fire the action
- Which fields are captured and how
- Any fields that couldn't be found and why
- Any assumptions made that the user should verify manually

---

## General Rules

- **Reusability first**: providers are named after engines/frameworks, not
  specific websites. Avoid hardcoding domain-specific selectors unless
  absolutely necessary.
- **Fail silently**: chains that can't extract data should produce `null`
  fields, not throw errors. Use optional chaining (`?.`) liberally.
- **Don't duplicate events**: if a search AJAX call fires multiple times for
  the same query, the built-in deduplication in `events.js` handles it — but
  be aware of overly broad AJAX triggers.
- **Always build before reporting**: a provider that doesn't compile is not done.
- **When data is missing**: capture what you can, use `null` for the rest, and
  tell the user what to verify manually. Don't block progress on data you can't
  find.
