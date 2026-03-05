# cursor-skills

Personal AI skills for [Cursor](https://cursor.com) and [Claude Code](https://claude.ai/code),
stored at `~/.cursor/skills/` so they are available globally across all projects.

Skills are reusable AI workflows. Each skill tells the agent what to do, when
to do it, and how to do it — without having to re-explain the context every
time. Cursor loads skills from this folder automatically; they can also be
invoked explicitly with `/skill-name`.

---

## Installation

```bash
git clone <repo-url> ~/.cursor/skills
```

Some skills require shell scripts to be executable:

```bash
chmod +x ~/.cursor/skills/*/scripts/*.sh
```

---

## Skills

### [`/session-devlog`](session-devlog/SKILL.md)

Generates a structured Markdown devlog at the end of a coding session and
saves it to `~/.devlogs/<YYYY-MM-DD>/<slug>.md`.

**Two modes:**
- **Agent session** — reads the current conversation and summarises what was
  built, decided, questioned, and discussed
- **Git commits** — reads all commits ahead of `master`/`main`, presents its
  interpretation for confirmation, then writes the devlog

**Output:** requirements/ticket reference · per-file change breakdown (what +
why + details) · Mermaid diagrams for flow/dependency changes · decisions table
· questions and concerns raised · notes

**Invoke:** `/session-devlog` · _"write a devlog"_ · _"log the session"_ ·
_"summarise what we did"_

```
session-devlog/
├── SKILL.md
└── scripts/
    ├── prepare-devlog-dir.sh   # creates ~/.devlogs/<today>/, returns path
    └── get-git-changes.sh      # collects commits + diffs ahead of master/main
```

---

### [`/self-assessment`](self-assessment/SKILL.md)

Reads all devlogs from `~/.devlogs/` for a given period and produces a
first-person self-assessment document suitable for performance reviews and PDE
(Personal Development Evaluation) conversations. Saves to
`~/.devlogs/assessments/<period>.md`.

**Accepts:** `Q1 2026` · `last 3 months` · `last 6 months` ·
`--from 2026-01-01 --to 2026-03-31`

**Output:** period summary · work grouped by theme · impact assessment per
theme · highlights · by-the-numbers table · patterns & growth · concerns raised
· areas to develop

**Invoke:** `/self-assessment` · _"write my self-assessment"_ · _"prepare my
PDE review"_ · _"what did I do this quarter"_

```
self-assessment/
├── SKILL.md
├── references/
│   └── beyond-glossary.md   # Beyond company acronym glossary (loaded at runtime)
└── scripts/
    └── collect-devlogs.sh   # filters ~/.devlogs/ by date range, streams content
```

---

### [`/beacon-provider`](beacon-provider/SKILL.md)

Creates or extends Beacon tracking providers — client-side JavaScript snippets
installed on short-term rental booking websites to capture searches, property
views, quotes, and conversions. Beacon lives at
`~/GitHub/beyondpricing/beacon`.

**Two modes:**
- **New provider** — opens the website with a Browser subagent, detects the
  framework and navigation model, generates a provider scaffold via
  `npm run gen-provider`, adds a `site-config.json` entry, builds, and
  implements the first requested action
- **Implement / update action** — opens the specific URL showing the target
  page state (Browser subagent) and reads the existing provider file (Explore
  subagent) in parallel, then implements or reimplements exactly the one action
  requested without touching any others

**Uses subagents:** Browser · Explore · Bash (build runs in background after edits)

**Invoke:** `/beacon-provider` · _"create a provider for [url]"_ ·
_"implement captureSearchResult"_ · _"take a look at [url] and implement
captureQuote"_

```
beacon-provider/
├── SKILL.md
└── references/
    ├── beacon-architecture.md     # system overview, folder map, site-config schema
    ├── provider-builder-api.md    # complete p.* builder API reference
    ├── event-schemas.md           # required fields for all 4 event types
    └── provider-patterns.md       # 6 implementation patterns with real code examples
```

---

## Folder Structure

```
~/.cursor/skills/
├── README.md
├── session-devlog/
│   ├── SKILL.md
│   └── scripts/
├── self-assessment/
│   ├── SKILL.md
│   ├── references/
│   └── scripts/
└── beacon-provider/
    ├── SKILL.md
    └── references/
```

---

### [`/async-standup`](async-standup/SKILL.md)

Generates an async standup message from devlogs, ready to paste into a Slack
standup channel.

**Flow:** resolves the correct "since" date (auto-handles Monday → Friday) →
reads devlogs → asks if anything is missing → asks for today/tomorrow plans →
outputs two bulleted-list responses.

**Output:** two plain `-` bullet lists (Slack-ready, no prose):
- *What did I do since `<date>`?*
- *What are my plans for today and tomorrow?*

**Invoke:** `/async-standup` · _"write my standup"_ · _"generate my standup message"_

```
async-standup/
├── SKILL.md
└── scripts/
    └── resolve-since-date.sh   # resolves yesterday or last Friday (on Mondays)
```

---

## Adding a New Skill

1. Create `<skill-name>/SKILL.md` with YAML frontmatter:
   ```yaml
   ---
   name: skill-name
   description: >
     One paragraph: what it does and when to invoke it.
   ---
   ```
2. Add domain knowledge to `<skill-name>/references/*.md`
3. Add shell helpers to `<skill-name>/scripts/*.sh` and `chmod +x` them
4. Add a section to this README under **Skills**

---

## For AI Agents Reading This

- Each skill's instructions are in `<skill-name>/SKILL.md` — load that file
  before acting on any invocation.
- Reference files (`*/references/*.md`) contain domain knowledge loaded on
  demand; they are not auto-loaded unless the SKILL.md instructs it.
- Scripts (`*/scripts/*.sh`) are executed by the agent as part of skill
  workflows — check each SKILL.md for the correct working directory.
- `~/.devlogs/` is the shared output directory for `session-devlog` and
  `self-assessment`. It lives outside this repo — do not modify its structure.
