#!/usr/bin/env bash
# Import a historical cask version from Homebrew/homebrew-cask git history.
# The only content change made is the token line: cask "<name>" -> "<name>@<version>".
#
# Usage: .github/scripts/import-cask.sh <name> <version>
# Run from the repository root.
set -euo pipefail

if [ $# -ne 2 ]; then
  echo "usage: $0 <name> <version>" >&2
  exit 2
fi

NAME="$1"
VERSION="$2"
TARGET_DIR="Casks/${NAME}"
TARGET_FILE="${TARGET_DIR}/${NAME}@${VERSION}.rb"

if [ -e "$TARGET_FILE" ]; then
  echo "error: ${TARGET_FILE} already exists" >&2
  exit 1
fi

FIRST_CHAR="$(printf '%s' "$NAME" | cut -c1)"
# New sharded layout first, then the pre-2023 flat layout.
CANDIDATE_PATHS=("Casks/${FIRST_CHAR}/${NAME}.rb" "Casks/${NAME}.rb")

CLONE_DIR="$(mktemp -d)"
# A failing EXIT trap would override the script's exit code; warn instead.
trap 'rm -rf "$CLONE_DIR" || echo "warning: failed to remove ${CLONE_DIR}" >&2' EXIT
echo "cloning Homebrew/homebrew-cask (blobless, no checkout)..." >&2
git clone --quiet --filter=blob:none --no-checkout \
  https://github.com/Homebrew/homebrew-cask.git "$CLONE_DIR"

# Prints the file content of the newest historical state containing the exact
# version line, or returns 1. git log -S lists commits that added OR removed
# the string, so for each candidate commit we also test its first parent.
find_content() {
  local path commit candidate content
  for path in "${CANDIDATE_PATHS[@]}"; do
    while IFS= read -r commit; do
      [ -n "$commit" ] || continue
      for candidate in "$commit" "${commit}^"; do
        content="$(git -C "$CLONE_DIR" show "${candidate}:${path}" 2>/dev/null || true)"
        [ -n "$content" ] || continue
        if printf '%s\n' "$content" | grep -qF "version \"${VERSION}\""; then
          echo "found ${path} at ${candidate}" >&2
          printf '%s\n' "$content"
          return 0
        fi
      done
    done < <(git -C "$CLONE_DIR" log --format=%H -S"version \"${VERSION}\"" -- "$path")
  done
  return 1
}

# Lists every version string ever added to the candidate paths (for the
# not-found error message).
list_versions() {
  local path
  for path in "${CANDIDATE_PATHS[@]}"; do
    git -C "$CLONE_DIR" log -p --format= -- "$path" 2>/dev/null || true
  done \
    | grep -E '^\+\s*version "' \
    | sed -E 's/^\+\s*version "([^"]+)".*/\1/' \
    | sort -u
}

if ! CONTENT="$(find_content)"; then
  {
    echo "error: version ${VERSION} of cask '${NAME}' not found in Homebrew/homebrew-cask history"
    echo "versions seen in history:"
    list_versions | sed 's/^/  /'
  } >&2
  exit 1
fi

mkdir -p "$TARGET_DIR"
printf '%s\n' "$CONTENT" \
  | sed -e "s|^cask \"${NAME}\" do\$|cask \"${NAME}@${VERSION}\" do|" > "$TARGET_FILE"

if [ "$(grep -c "^cask \"${NAME}@${VERSION}\" do\$" "$TARGET_FILE")" -ne 1 ]; then
  rm -f "$TARGET_FILE"
  echo "error: token rewrite failed (expected exactly one 'cask \"${NAME}@${VERSION}\" do' line)" >&2
  exit 1
fi

echo "wrote ${TARGET_FILE}"
