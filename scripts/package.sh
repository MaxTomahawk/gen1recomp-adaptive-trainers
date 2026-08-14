#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
ENGINE_ROOT=${GEN1RECOMP_ROOT:-"$REPO_ROOT/.engine/gen1recomp"}

GEN1RECOMP_ROOT="$ENGINE_ROOT" "$REPO_ROOT/scripts/check.sh"

VERSION=$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$REPO_ROOT/manifest.json")
if [[ -z "$VERSION" ]]; then
  echo "manifest.json does not contain a version" >&2
  exit 2
fi

mkdir -p "$REPO_ROOT/dist"
if [[ -z "${SOURCE_DATE_EPOCH:-}" ]]; then
  SOURCE_DATE_EPOCH=$(git -C "$REPO_ROOT" log -1 --format=%ct)
  export SOURCE_DATE_EPOCH
fi

OUTPUT="$REPO_ROOT/dist/adaptive_trainers-$VERSION.modpkg"
python3 "$ENGINE_ROOT/tools/modkit.py" --repo "$ENGINE_ROOT" \
  pack "$REPO_ROOT" --base fixture --output "$OUTPUT"

echo "$OUTPUT"
