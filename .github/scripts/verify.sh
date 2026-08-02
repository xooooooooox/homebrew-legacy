#!/usr/bin/env bash
# Verify an imported cask/formula: brew style + brew audit + brew fetch.
# Writes a markdown report; check failures are recorded in the report and in
# the overall=pass|fail output, NOT via a non-zero exit (by design the PR is
# still opened and a human decides — see the design spec).
#
# Usage: .github/scripts/verify.sh <type> <name> <version> <report-file>
#   type: cask | formula
# Note: audit/fetch resolve the token through the installed tap, so the file
# must be visible there (true in CI via setup-homebrew; locally only for
# already-pushed entries).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [ $# -ne 4 ]; then
  echo "usage: $0 <type> <name> <version> <report-file>" >&2
  exit 2
fi

TYPE="$1"
NAME="$2"
VERSION="$3"
REPORT="$4"
TOKEN="${NAME}@${VERSION}"
TAP="$(derive_tap_name)"
QUALIFIED="${TAP}/${TOKEN}"

case "$TYPE" in
  cask)
    FILE="Casks/${NAME}/${TOKEN}.rb"
    TYPE_FLAG="--cask"
    ;;
  formula)
    FILE="Formula/${NAME}/${TOKEN}.rb"
    TYPE_FLAG="--formula"
    ;;
  *)
    echo "error: type must be 'cask' or 'formula', got '${TYPE}'" >&2
    exit 2
    ;;
esac

OVERALL=pass
printf '## Verification: %s\n' "$QUALIFIED" > "$REPORT"

check() {
  local label="$1"
  shift
  local out status
  echo "running: $*" >&2
  if out="$("$@" 2>&1)"; then
    status="✅ pass"
  else
    status="❌ fail"
    OVERALL=fail
  fi
  {
    printf '\n### %s — %s\n' "$label" "$status"
    printf '```\n$ %s\n' "$*"
    printf '%s\n' "$out" | tail -n 40
    printf '```\n'
  } >> "$REPORT"
}

check "brew style" brew style "$FILE"
check "brew audit" brew audit "$TYPE_FLAG" "$QUALIFIED"
check "brew fetch" brew fetch "$TYPE_FLAG" "$QUALIFIED"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat "$REPORT" >> "$GITHUB_STEP_SUMMARY"
fi
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "overall=${OVERALL}" >> "$GITHUB_OUTPUT"
fi
echo "verification overall: ${OVERALL}"
