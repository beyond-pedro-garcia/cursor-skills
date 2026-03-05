#!/usr/bin/env bash
# prepare-devlog-dir.sh
#
# Creates ~/.devlogs/<today>/ if it doesn't exist and prints the directory path.
# Usage: source this script or capture its output to get the target directory.
#
# Output (stdout):
#   Line 1 — absolute path to today's devlog directory
#   Line 2 — today's date string (YYYY-MM-DD)

set -euo pipefail

TODAY="$(date +%Y-%m-%d)"
DEVLOG_DIR="${HOME}/.devlogs/${TODAY}"

mkdir -p "${DEVLOG_DIR}"

echo "${DEVLOG_DIR}"
echo "${TODAY}"
