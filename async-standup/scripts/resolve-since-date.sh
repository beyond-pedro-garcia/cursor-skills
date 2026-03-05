#!/usr/bin/env bash
# resolve-since-date.sh
#
# Resolves the correct "since" date for a standup message.
# Defaults:
#   - Monday      → previous Friday
#   - Any other weekday → yesterday
#
# Usage:
#   bash resolve-since-date.sh            # auto-resolve
#   bash resolve-since-date.sh 2026-03-03 # use explicit date
#
# Output (stdout):
#   Line 1 — resolved since-date (YYYY-MM-DD)
#   Line 2 — today's date (YYYY-MM-DD)

set -euo pipefail

TODAY="$(date +%Y-%m-%d)"
DAY_OF_WEEK="$(date +%u)"  # 1=Mon ... 7=Sun

if [[ $# -ge 1 ]]; then
  SINCE="$1"
else
  if [[ "$DAY_OF_WEEK" -eq 1 ]]; then
    # Monday — go back to Friday
    SINCE="$(date -v -3d +%Y-%m-%d 2>/dev/null || date --date='3 days ago' +%Y-%m-%d)"
  else
    SINCE="$(date -v -1d +%Y-%m-%d 2>/dev/null || date --date='1 day ago' +%Y-%m-%d)"
  fi
fi

echo "$SINCE"
echo "$TODAY"
