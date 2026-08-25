#!/usr/bin/env bash
# Reattach a pourable historical core bottle to an imported formula, so
# devices on a macOS that Homebrew no longer bottles for (default: monterey)
# keep plain `brew install` without compiling. Homebrew never deletes
# published bottles: the historical blob stays on ghcr.io. This script finds
# the newest core version still carrying a ${BOTTLE_TAG} bottle, imports it
# (via import-formula.sh) if needed, downloads the blob, repacks the keg top
# dir to the tap's formula name (brew pours into Cellar/<formula-name>/), and
# injects a `bottle do` block pointing at this repo's release assets.
#
# The uploaded asset name must be brew's Bottle::Filename#url_encode form:
# "<formula-name>-<pkg_version>.<tag>.bottle[.N].tar.gz" (single dash; the
# double-dash form is only the local cache name).
#
# Usage: .github/scripts/rebottle.sh <name> [<version>]
#   Without <version>: walks core git history backwards from ${HISTORY_UNTIL}
#   and picks the newest version whose bottle block has a ${BOTTLE_TAG} sha.
# Env: BOTTLE_TAG (default monterey); HISTORY_UNTIL (default 2024-10-01,
#   Homebrew 4.4 dropped monterey then); GITHUB_TOKEN (optional, only for
#   GitHub API rate limits). Requires: curl, python3, tar, shasum.
# Outputs (also to $GITHUB_OUTPUT when set): version, pkg_version,
#   bottle_file (repacked tarball path), release_tag.
# Uploading the asset is the caller's job (CI: gh release upload).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "usage: $0 <name> [<version>]" >&2
  exit 2
fi

NAME="$1"
WANT_VERSION="${2:-}"
BOTTLE_TAG="${BOTTLE_TAG:-monterey}"
HISTORY_UNTIL="${HISTORY_UNTIL:-2024-10-01}"

case "$NAME" in
  *@*) echo "error: names containing '@' are not supported (ghcr package path differs)" >&2; exit 2 ;;
  lib*) SHARD="lib" ;;
  *) SHARD="${NAME:0:1}" ;;
esac
CORE_PATH="Formula/${SHARD}/${NAME}.rb"

api() {
  curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer ${GITHUB_TOKEN}"} "$@"
}

# Walk core history newest-first; a candidate commit's formula must carry a
# ${BOTTLE_TAG} sha AND its blob's keg dir must match the formula's version --
# core bumps land as two commits (url bump first, then "update X bottle"), so
# the newest text with an old bottle block is an inconsistent intermediate.
WORK="$(mktemp -d)"
VERSION="" BOTTLE_SHA="" CELLAR="" REBUILD="" PKGVER=""
for page in 1 2 3; do
  SHAS="$(api "https://api.github.com/repos/Homebrew/homebrew-core/commits?path=${CORE_PATH}&until=${HISTORY_UNTIL}T00:00:00Z&per_page=50&page=${page}" |
    python3 -c 'import sys,json; [print(c["sha"]) for c in json.load(sys.stdin)]')"
  [ -n "$SHAS" ] || break
  while read -r sha; do
    TEXT="$(curl -fsSL "https://raw.githubusercontent.com/Homebrew/homebrew-core/${sha}/${CORE_PATH}")" || continue
    grep -Eq "^[[:space:]]*sha256 (cellar: [^,]+, )?${BOTTLE_TAG}: " <<<"$TEXT" || continue
    VERSION="$(sed -nE 's|.*archive/refs/tags/v?([0-9][^"]*)\.tar.*|\1|p; s|^[[:space:]]*version "([^"]+)"|\1|p' <<<"$TEXT" | head -1)"
    if [ -n "$WANT_VERSION" ] && [ "$VERSION" != "$WANT_VERSION" ]; then continue; fi
    BOTTLE_SHA="$(sed -nE "s/^[[:space:]]*sha256 (cellar: [^,]+, )?${BOTTLE_TAG}: +\"([0-9a-f]{64})\".*/\2/p" <<<"$TEXT" | head -1)"
    CELLAR="$(sed -nE "s/^[[:space:]]*sha256 cellar: +([^,]+), +${BOTTLE_TAG}: .*/\1/p" <<<"$TEXT" | head -1)"
    REBUILD="$(sed -nE 's/^[[:space:]]*rebuild +([0-9]+)[[:space:]]*$/\1/p' <<<"$TEXT" | head -1)"
    [ -n "$VERSION" ] && [ -n "$BOTTLE_SHA" ] || continue
    GHCR_TOKEN="$(curl -fsSL "https://ghcr.io/token?service=ghcr.io&scope=repository:homebrew/core/${NAME}:pull" |
      python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')"
    curl -fsSL -H "Authorization: Bearer ${GHCR_TOKEN}" \
      "https://ghcr.io/v2/homebrew/core/${NAME}/blobs/sha256:${BOTTLE_SHA}" -o "${WORK}/orig.tar.gz" || continue
    echo "${BOTTLE_SHA}  ${WORK}/orig.tar.gz" | shasum -a 256 -c - >/dev/null
    rm -rf "${WORK:?}/${NAME}"
    tar -xzf "${WORK}/orig.tar.gz" -C "$WORK"
    PKGVER="$(basename "$(ls -d "${WORK}/${NAME}"/*/)")"
    case "$PKGVER" in
      "$VERSION" | "${VERSION}_"*) break 2 ;;
      *)
        echo "skipping commit ${sha}: formula says ${VERSION} but bottle keg is ${PKGVER} (intermediate bump commit)" >&2
        PKGVER=""
        continue
        ;;
    esac
  done <<<"$SHAS"
done
if [ -z "$PKGVER" ]; then
  echo "error: no consistent core revision of ${NAME}${WANT_VERSION:+ v${WANT_VERSION}} with a '${BOTTLE_TAG}' bottle found before ${HISTORY_UNTIL}" >&2
  exit 1
fi
echo "found ${NAME} ${VERSION}: ${BOTTLE_TAG} bottle sha ${BOTTLE_SHA}${CELLAR:+, cellar ${CELLAR}}${REBUILD:+, rebuild ${REBUILD}}"

TARGET_FILE="Formula/${NAME}/${NAME}@${VERSION}.rb"
if [ ! -f "$TARGET_FILE" ]; then
  "${SCRIPT_DIR}/import-formula.sh" "$NAME" "$VERSION"
fi
if grep -q "^  bottle do" "$TARGET_FILE"; then
  echo "error: ${TARGET_FILE} already has a bottle block" >&2
  exit 1
fi

TOKEN_NAME="${NAME}@${VERSION}"
mv "${WORK}/${NAME}" "${WORK}/${TOKEN_NAME}"
EXT=".${BOTTLE_TAG}.bottle${REBUILD:+.${REBUILD}}.tar.gz"
BOTTLE_FILE="${WORK}/${TOKEN_NAME}-${PKGVER}${EXT}"
tar -czf "$BOTTLE_FILE" -C "$WORK" "$TOKEN_NAME"
NEW_SHA="$(shasum -a 256 "$BOTTLE_FILE" | cut -d' ' -f1)"

TAP="$(derive_tap_name)"
REPO_SLUG="${TAP%%/*}/homebrew-${TAP#*/}"
RELEASE_TAG="formula-${TOKEN_NAME}"
ROOT_URL="https://github.com/${REPO_SLUG}/releases/download/${RELEASE_TAG}"

export ROOT_URL CELLAR BOTTLE_TAG NEW_SHA REBUILD TARGET_FILE
python3 - <<'PY'
import os, re
path = os.environ["TARGET_FILE"]
text = open(path).read()
lines = [f'  bottle do', f'    root_url "{os.environ["ROOT_URL"]}"']
if os.environ.get("REBUILD"):
    lines.append(f'    rebuild {os.environ["REBUILD"]}')
cellar = os.environ.get("CELLAR")
cellar_part = f'cellar: {cellar}, ' if cellar else ''
lines.append(f'    sha256 {cellar_part}{os.environ["BOTTLE_TAG"]}: "{os.environ["NEW_SHA"]}"')
lines.append('  end')
block = "\n".join(lines) + "\n\n"
# Core component order puts bottle right before dependencies/install.
m = re.search(r'^  (depends_on|uses_from_macos|on_macos|def install)\b', text, re.M)
if not m:
    raise SystemExit("no insertion anchor found in " + path)
text = text[:m.start()] + block + text[m.start():]
open(path, "w").write(text)
PY
echo "injected bottle block into ${TARGET_FILE}"

RUNTIME_DEPS="$(grep -E '^[[:space:]]*depends_on "' "$TARGET_FILE" | grep -v ':build\|:test' || true)"
if [ -n "$RUNTIME_DEPS" ]; then
  echo "WARNING: runtime dependencies resolve to CURRENT homebrew/core and will source-build on the target device:" >&2
  echo "$RUNTIME_DEPS" >&2
  echo "Rebottle each dependency and rewrite depends_on to this tap's names, or reconsider." >&2
fi

echo "bottle file: ${BOTTLE_FILE}"
if [ -n "${GITHUB_OUTPUT:-}" ]; then
  {
    echo "version=${VERSION}"
    echo "pkg_version=${PKGVER}"
    echo "bottle_file=${BOTTLE_FILE}"
    echo "release_tag=${RELEASE_TAG}"
  } >> "$GITHUB_OUTPUT"
fi
