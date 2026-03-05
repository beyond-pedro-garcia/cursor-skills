#!/usr/bin/env bash
# collect-devlogs.sh
#
# Reads all devlogs under ~/.devlogs/ within a given date range and prints
# them to stdout in a structured format for the agent to analyse.
#
# Usage:
#   bash collect-devlogs.sh --from YYYY-MM-DD --to YYYY-MM-DD
#   bash collect-devlogs.sh --quarter Q1 [--year YYYY]
#   bash collect-devlogs.sh --last 3months | 6months | 1year
#
# Output:
#   === ASSESSMENT PERIOD ===   metadata about the resolved range
#   === DEVLOG INDEX ===         list of all files found with dates
#   === DEVLOGS ===              full content of each file, delimited

set -euo pipefail

DEVLOGS_ROOT="${HOME}/.devlogs"
TODAY="$(date +%Y-%m-%d)"
CURRENT_YEAR="$(date +%Y)"

FROM=""
TO=""

# ── Argument parsing ─────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)   FROM="$2"; shift 2 ;;
    --to)     TO="$2";   shift 2 ;;
    --quarter)
      QUARTER="$2"; shift 2
      YEAR="${CURRENT_YEAR}"
      # optional --year override that may follow
      if [[ $# -ge 2 && "$1" == "--year" ]]; then
        YEAR="$2"; shift 2
      fi
      case "${QUARTER^^}" in
        Q1) FROM="${YEAR}-01-01"; TO="${YEAR}-03-31" ;;
        Q2) FROM="${YEAR}-04-01"; TO="${YEAR}-06-30" ;;
        Q3) FROM="${YEAR}-07-01"; TO="${YEAR}-09-30" ;;
        Q4) FROM="${YEAR}-10-01"; TO="${YEAR}-12-31" ;;
        *)
          echo "ERROR: Unknown quarter '${QUARTER}'. Use Q1, Q2, Q3, or Q4." >&2
          exit 1
          ;;
      esac
      ;;
    --last)
      SPEC="$2"; shift 2
      case "${SPEC,,}" in
        *month*)
          N="${SPEC//[^0-9]/}"
          FROM="$(date -v -"${N}"m +%Y-%m-%d 2>/dev/null || date --date="${N} months ago" +%Y-%m-%d)"
          TO="${TODAY}"
          ;;
        *year*)
          N="${SPEC//[^0-9]/}"
          FROM="$(date -v -"${N}"y +%Y-%m-%d 2>/dev/null || date --date="${N} years ago" +%Y-%m-%d)"
          TO="${TODAY}"
          ;;
        *week*)
          N="${SPEC//[^0-9]/}"
          DAYS=$(( N * 7 ))
          FROM="$(date -v -"${DAYS}"d +%Y-%m-%d 2>/dev/null || date --date="${DAYS} days ago" +%Y-%m-%d)"
          TO="${TODAY}"
          ;;
        *)
          echo "ERROR: Unknown --last spec '${SPEC}'. Try '3months', '6months', '1year', '4weeks'." >&2
          exit 1
          ;;
      esac
      ;;
    *)
      echo "ERROR: Unknown argument '$1'" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$FROM" || -z "$TO" ]]; then
  echo "ERROR: Must specify a date range. Examples:" >&2
  echo "  --from 2026-01-01 --to 2026-03-31" >&2
  echo "  --quarter Q1 [--year 2026]" >&2
  echo "  --last 3months" >&2
  exit 1
fi

# ── Collect matching day-folders ─────────────────────────────────────────────
if [[ ! -d "${DEVLOGS_ROOT}" ]]; then
  echo "ERROR: Devlogs directory '${DEVLOGS_ROOT}' does not exist." >&2
  exit 1
fi

mapfile -t DAY_DIRS < <(
  find "${DEVLOGS_ROOT}" -maxdepth 1 -mindepth 1 -type d \
    | grep -E '/[0-9]{4}-[0-9]{2}-[0-9]{2}$' \
    | sort
)

MATCHED_FILES=()
for DIR in "${DAY_DIRS[@]}"; do
  DIRDATE="$(basename "${DIR}")"
  if [[ "${DIRDATE}" > "${FROM}" || "${DIRDATE}" == "${FROM}" ]] && [[ "${DIRDATE}" < "${TO}" || "${DIRDATE}" == "${TO}" ]]; then
    while IFS= read -r -d '' FILE; do
      MATCHED_FILES+=("${FILE}")
    done < <(find "${DIR}" -maxdepth 1 -name "*.md" -print0 | sort -z)
  fi
done

# ── Emit structured output ───────────────────────────────────────────────────
echo "=== ASSESSMENT PERIOD ==="
echo "From : ${FROM}"
echo "To   : ${TO}"
echo "Total devlog files found: ${#MATCHED_FILES[@]}"
echo ""

if [[ ${#MATCHED_FILES[@]} -eq 0 ]]; then
  echo "No devlogs found in the specified range."
  exit 0
fi

echo "=== DEVLOG INDEX ==="
for FILE in "${MATCHED_FILES[@]}"; do
  DIRDATE="$(basename "$(dirname "${FILE}")")"
  FILENAME="$(basename "${FILE}")"
  echo "  [${DIRDATE}] ${FILENAME}"
done
echo ""

echo "=== DEVLOGS ==="
for FILE in "${MATCHED_FILES[@]}"; do
  DIRDATE="$(basename "$(dirname "${FILE}")")"
  FILENAME="$(basename "${FILE}")"
  echo "--- BEGIN: ${DIRDATE}/${FILENAME} ---"
  cat "${FILE}"
  echo ""
  echo "--- END: ${DIRDATE}/${FILENAME} ---"
  echo ""
done
