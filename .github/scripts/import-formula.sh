#!/usr/bin/env bash
# Import a historical formula version from Homebrew/homebrew-core history
# using the official `brew extract`, then move the file into this repo's
# Formula/<name>/<name>@<version>.rb layout. Content is not modified further.
#
# Usage: .github/scripts/import-formula.sh <name> <version>
# Requires: this repository installed as a Homebrew tap (locally via
# `brew tap`; in CI, Homebrew/actions/setup-homebrew places the checkout
# in the tap location). May clone homebrew/core on first run (large).
# Run from the repository root.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [ $# -ne 2 ]; then
  echo "usage: $0 <name> <version>" >&2
  exit 2
fi

NAME="$1"
VERSION="$2"
TARGET_FILE="Formula/${NAME}/${NAME}@${VERSION}.rb"

if [ -e "$TARGET_FILE" ]; then
  echo "error: ${TARGET_FILE} already exists" >&2
  exit 1
fi

TAP="$(derive_tap_name)"
TAP_DIR="$(brew --repository "$TAP")"
if [ ! -d "$TAP_DIR" ]; then
  echo "error: tap ${TAP} not installed (expected at ${TAP_DIR}); run: brew tap ${TAP}" >&2
  exit 1
fi

brew extract --version="$VERSION" "$NAME" "$TAP"

EXTRACTED="${TAP_DIR}/Formula/${NAME}@${VERSION}.rb"
if [ ! -f "$EXTRACTED" ]; then
  echo "error: brew extract reported success but ${EXTRACTED} does not exist" >&2
  exit 1
fi

mkdir -p "Formula/${NAME}"
mv "$EXTRACTED" "$TARGET_FILE"
echo "wrote ${TARGET_FILE}"
