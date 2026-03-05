#!/usr/bin/env bash
# get-git-changes.sh
#
# Collects all commits and their diffs that are ahead of the merge base with
# master (or main). Outputs structured text for the agent to analyse.
#
# Usage: bash scripts/get-git-changes.sh [base-branch]
#   base-branch defaults to "master", falls back to "main" if master not found.
#
# Output sections (delimited for easy parsing):
#   === REPO INFO ===
#   === COMMITS ===
#   === FULL DIFF ===

set -euo pipefail

# ── Resolve repo root ────────────────────────────────────────────────────────
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo "ERROR: Not inside a git repository." >&2
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# ── Resolve base branch ──────────────────────────────────────────────────────
BASE="${1:-}"
if [[ -z "$BASE" ]]; then
  if git rev-parse --verify master &>/dev/null; then
    BASE="master"
  elif git rev-parse --verify main &>/dev/null; then
    BASE="main"
  else
    echo "ERROR: Could not find a 'master' or 'main' branch. Pass the base branch as the first argument." >&2
    exit 1
  fi
fi

# Check remote counterpart too (origin/master or origin/main) and pick the one
# that gives more commits so we don't miss anything when local base is stale.
REMOTE_BASE="origin/${BASE}"
if git rev-parse --verify "$REMOTE_BASE" &>/dev/null; then
  LOCAL_COUNT=$(git rev-list --count "${BASE}..HEAD" 2>/dev/null || echo 0)
  REMOTE_COUNT=$(git rev-list --count "${REMOTE_BASE}..HEAD" 2>/dev/null || echo 0)
  # Use whichever gives fewer ahead commits (i.e. the more up-to-date base)
  if [[ "$REMOTE_COUNT" -lt "$LOCAL_COUNT" ]]; then
    BASE="$REMOTE_BASE"
  fi
fi

MERGE_BASE="$(git merge-base "$BASE" HEAD)"

# ── Emit structured output ───────────────────────────────────────────────────
echo "=== REPO INFO ==="
echo "Repository root : $REPO_ROOT"
echo "Current branch  : $CURRENT_BRANCH"
echo "Base branch     : $BASE"
echo "Merge base SHA  : $MERGE_BASE"
echo ""

echo "=== COMMITS ==="
git log "${MERGE_BASE}..HEAD" \
  --format="commit %H%nauthor: %an <%ae>%ndate: %ad%nsubject: %s%nbody:%n%b%n---" \
  --date=iso
echo ""

echo "=== CHANGED FILES ==="
git diff --stat "${MERGE_BASE}..HEAD"
echo ""

echo "=== FULL DIFF ==="
# Exclude lock files and generated files to keep output manageable
git diff "${MERGE_BASE}..HEAD" \
  -- \
  ':!*.lock' \
  ':!package-lock.json' \
  ':!yarn.lock' \
  ':!pnpm-lock.yaml' \
  ':!*.min.js' \
  ':!*.min.css' \
  ':!dist/' \
  ':!build/' \
  ':!*.snap'
