---
name: async-standup
description: >
  Use this skill to generate an async standup message from devlogs. Invoke
  when the user says things like "write my standup", "generate my standup
  message", "async standup", or "/async-standup". Reads devlogs since the
  last working day (or a specified date), asks if anything is missing, asks
  for today/tomorrow plans, then produces two terse bulleted-list responses
  ready to paste into a Slack standup channel.
---

# Async Standup Skill

## Purpose

Generate the two standup responses from devlog history:
1. **What did you do since `<date>`?**
2. **What are your plans for today and tomorrow?**

Output is strictly bulleted lists — one or two lines per bullet, no prose.

---

## Step 1 — Resolve the since-date

Run:
```bash
bash ~/.cursor/skills/async-standup/scripts/resolve-since-date.sh [YYYY-MM-DD]
```

The script auto-resolves:
- **Monday** → previous Friday (covers the weekend gap)
- **Any other weekday** → yesterday

Pass an explicit date if the user specified one (e.g. "since Tuesday",
"since March 3rd"). Convert natural language dates to `YYYY-MM-DD` before
passing.

Note both output lines: `SINCE_DATE` and `TODAY`.

---

## Step 2 — Collect devlogs

Run:
```bash
bash ~/.cursor/skills/self-assessment/scripts/collect-devlogs.sh \
  --from <SINCE_DATE> --to <TODAY>
```

If the script reports zero devlogs, continue — the user may have done work
not captured in devlogs, and you will ask about it in Step 3.

---

## Step 3 — Synthesise activities from devlogs

Read all devlogs collected. For each one, extract a **one-line summary** of
what was done — the essence of the work, not the implementation details.

Group by theme if multiple devlogs cover clearly related work. Keep the
internal list concise — each item will become one standup bullet.

Beyond-specific acronyms (ORC tickets, ABP, SPP, LAMEN, etc.) are fine to
keep as-is — the standup audience knows them. Do not expand them.

---

## Step 4 — Ask if anything is missing

Present your synthesised list to the user and ask:

> "Here's what I found in your devlogs since `<SINCE_DATE>`:
>
> - `<item 1>`
> - `<item 2>`
> - ...
>
> Did you work on anything else that's not captured here?"

Wait for the response. If the user adds items, append them to the list.
If they say nothing is missing, proceed.

---

## Step 5 — Ask for today/tomorrow plans

Ask:

> "What are your plans for today and tomorrow?"

Wait for the response. Accept bullet points, prose, or a quick list —
you will format it regardless.

---

## Step 6 — Generate the standup message

Write the final message using **only bulleted lists**. Rules:
- Each bullet is **one to two lines maximum** — trim ruthlessly
- Lead with the action or outcome, not the context
- No headers, no prose paragraphs, no preamble
- Use plain language; technical terms are fine but avoid implementation minutiae
- For the "since" response: order bullets from most impactful to least
- For the "plans" response: order bullets by priority or logical sequence

Output format:

```
**What did I do since `<SINCE_DATE>`?**
- <one-line summary>
- <one-line summary>
- ...

**What are my plans for today and tomorrow?**
- <one-line plan>
- <one-line plan>
- ...
```

Do not add anything outside these two blocks — the output must be
ready to paste directly into a Slack standup channel. No markdown
headings, no commentary, no sign-off. Slack will render the bullet
points; keep formatting to plain `-` bullets only (no bold, no code
blocks unless a specific term warrants it).
