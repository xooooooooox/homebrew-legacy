#!/usr/bin/env bash
# Shared helpers for import/verify scripts. Source this file; do not execute.

# Prints the tap name as "<owner>/<tap>", e.g. "someowner/legacy".
# Resolution order: $TAP_NAME override -> $GITHUB_REPOSITORY (CI) ->
# origin remote URL. The repo name "homebrew-<tap>" maps to tap "<owner>/<tap>".
derive_tap_name() {
  if [ -n "${TAP_NAME:-}" ]; then
    printf '%s\n' "$TAP_NAME"
    return 0
  fi
  local slug
  if [ -n "${GITHUB_REPOSITORY:-}" ]; then
    slug="$GITHUB_REPOSITORY"
  else
    local url
    url="$(git remote get-url origin)"
    slug="${url%.git}"
    slug="${slug#*github.com[:/]}"
  fi
  local owner="${slug%%/*}"
  local repo="${slug#*/}"
  if [ "$owner" = "$slug" ] || [ -z "$owner" ] || [ -z "$repo" ]; then
    echo "error: cannot derive tap name from '${slug}'" >&2
    return 1
  fi
  printf '%s/%s\n' "$owner" "${repo#homebrew-}"
}
