---
name: self-assessment
description: >
  Use this skill to generate a self-assessment or performance review document
  by reading all devlogs from a given timeframe under ~/.devlogs/. Invoke when
  the user says things like "write my self-assessment", "prepare my PDE review",
  "what did I do this quarter", "summarise my work for the last 6 months",
  "generate my performance review", or "/self-assessment". Accepts natural
  timeframes: a quarter (Q1, Q2...), a number of months/weeks, or explicit
  dates. Saves the output to ~/.devlogs/assessments/<period>.md.
---

# Self-Assessment Skill

## Purpose

Read all devlogs in `~/.devlogs/` for a given period and produce a thorough
self-assessment document — suitable for performance reviews, PDE conversations,
and retrospective analysis — saved to `~/.devlogs/assessments/<period>.md`.

---

## Step 1 — Resolve the timeframe

If the user did not specify a period, ask:

> "What period should I cover? Examples: Q1 2026, last 3 months, January to
> March, or give me specific dates."

Once you have the period, translate it to `--from` / `--to` dates or the
appropriate flag and run the collector script:

```bash
# Examples:
bash ~/.cursor/skills/self-assessment/scripts/collect-devlogs.sh --quarter Q1 --year 2026
bash ~/.cursor/skills/self-assessment/scripts/collect-devlogs.sh --last 6months
bash ~/.cursor/skills/self-assessment/scripts/collect-devlogs.sh --from 2026-01-01 --to 2026-03-31
```

If the script reports zero devlogs, tell the user:

> "I found no devlogs for that period under ~/.devlogs/. You may need to run
> /session-devlog on your sessions first, or try a wider date range."

Then stop.

---

## Step 2 — Load the Beyond glossary

Before reading any devlogs, load the company glossary so you can correctly
interpret all acronyms and domain terms that appear in the session logs:

```
references/beyond-glossary.md
```

Use it throughout analysis and writing. When an acronym from the glossary
appears in a devlog, expand it in the assessment so the document is readable
without prior knowledge of Beyond's internal vocabulary.

---

## Step 3 — Read and ingest all devlogs


Parse the script output. Each devlog is delimited by:

```
--- BEGIN: YYYY-MM-DD/filename.md ---
...content...
--- END: YYYY-MM-DD/filename.md ---
```

Build an internal map of every piece of work: the ticket or goal, files
touched, what changed, decisions made, concerns raised, and any stated status.

---

## Step 4 — Analyse and synthesise

Before writing, derive the following from the raw devlogs:

### 4a. Theme clusters
Group work into **thematic areas** — e.g. "Frontend performance", "Onboarding
flow", "Auth refactor", "Infrastructure". A single piece of work may belong to
more than one theme. These will become the top-level sections of the assessment.

### 4b. Impact signals
For each piece of work, infer its impact level and type. Use these signals:

- **Scope:** how many files, modules, or products were touched
- **Complexity:** were non-obvious decisions made? Were there bugs or edge cases
  caught? Were TypeScript / type-system constraints navigated?
- **User/business facing:** did the change affect UX, copy, onboarding, billing,
  or other customer-visible surfaces?
- **Risk / criticality:** was the change on a critical path, a data pipeline, or
  a shared library?
- **Ticket origin:** JIRA/GitHub ticket references indicate planned,
  business-driven work; diagrams indicate architectural significance
- **Concerns raised:** questions and worries logged during the session indicate
  careful, thoughtful engineering

Do not invent impact that cannot be inferred from the devlogs. Where impact
is unclear, say so honestly.

### 4c. Quantitative signals
Count and surface:
- Total devlogs (= distinct sessions/features)
- Number of unique JIRA/GitHub tickets addressed
- Number of distinct products or codebases touched
- Number of files changed across all sessions (if available from devlogs)

### 4d. Recurring patterns and growth signals
Look across all devlogs for patterns that speak to professional growth:
- Repeated problem domains mastered
- New technologies or patterns encountered and resolved
- Evidence of debugging thoroughness (e.g. root-cause analysis, test fixes)
- Evidence of cross-functional awareness (PR feedback incorporated, Figma
  specs followed, i18n considerations)

---

## Step 5 — Write the assessment

Use the template below. Adapt the theme sections to what actually appears in
the devlogs. Write in **first person**, using language appropriate for a
professional self-assessment. Be specific and evidence-backed — every claim
should trace to something in the devlogs. Avoid inflating impact; honest,
grounded assessments are more credible and more useful.

````markdown
# Self-Assessment: <Period>

**Period:** <e.g. Q1 2026 · January 1 – March 31>
**Generated:** <today's date>
**Sessions reviewed:** <N devlogs across N days>

---

## Summary

<!-- 3–5 sentences: what was the overall focus of the period, and what was the
     headline impact? Written as a concise opening statement suitable for a
     review document. -->

---

## Work by Theme

<!-- One section per theme cluster. Repeat the block below for each. -->

### <Theme Name>

**Tickets / Goals:** <list of JIRA keys or short goal descriptions>

**What I did:**
<!-- Specific, concrete description of the work. Not a list of files — a
     description of the problem solved and what was built or changed. -->

**Impact:**
<!-- What did this enable, fix, or improve? Who or what does it affect?
     Be honest about scale: "small but important fix" is fine. -->

**Notable decisions or challenges:**
<!-- Highlight any non-trivial decision, tricky bug, architectural choice, or
     constraint navigated. This is where technical depth shows. -->

---

## Highlights

<!-- 3–5 bullet points of the most significant individual achievements across
     all themes. These should be the things most worth raising in a PDE. -->

- ...

---

## By the Numbers

| Metric | Value |
|--------|-------|
| Sessions / features logged | |
| JIRA / GitHub tickets | |
| Products / codebases touched | |
| Files changed (approx.) | |

---

## Patterns & Growth

<!-- What do the devlogs reveal about how you work and what you learned?
     Include technical growth (new tools, patterns) and process growth
     (how you handle feedback, debugging, cross-functional work).
     2–4 paragraphs. -->

---

## Concerns & Open Questions from the Period

<!-- Aggregate the questions and worries logged during sessions that were
     significant or recurring. These can surface areas of uncertainty worth
     discussing in a PDE conversation. -->

- ...

---

## Areas to Develop

<!-- Honest, forward-looking observations drawn from the devlogs. What came up
     repeatedly as uncertain? What took longer than it should have? What was
     out of scope but clearly needed? 2–4 bullets. -->

- ...
````

---

## Step 6 — Save the file

Create the output directory and write the file:

```bash
mkdir -p ~/.devlogs/assessments
```

File name format: `<from>_<to>.md` — e.g. `2026-01-01_2026-03-31.md` or
`2026-Q1.md` for quarter-based runs.

Full path: `~/.devlogs/assessments/<filename>.md`

Confirm to the user:

```
Self-assessment saved → ~/.devlogs/assessments/<filename>.md
Covered <N> devlogs across <date range>.
```
