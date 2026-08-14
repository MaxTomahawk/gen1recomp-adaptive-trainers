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

if [[ -z "${SOURCE_DATE_EPOCH:-}" ]]; then
  SOURCE_DATE_EPOCH=$(git -C "$REPO_ROOT" log -1 --format=%ct)
  export SOURCE_DATE_EPOCH
fi

OUTPUT="$REPO_ROOT/dist/adaptive_trainers-$VERSION.modpkg"
STAGE_PARENT=$(mktemp -d /tmp/adaptive-trainers-package.XXXXXX)
cleanup() {
  if [[ "$STAGE_PARENT" == /tmp/adaptive-trainers-package.* ]]; then
    rm -rf -- "$STAGE_PARENT"
  fi
}
trap cleanup EXIT

PACK_ROOT="$STAGE_PARENT/adaptive_trainers"
mkdir -p "$PACK_ROOT"
for file in manifest.json mod.card main.lua README.md CHANGELOG.md .luarc.json; do
  cp "$REPO_ROOT/$file" "$PACK_ROOT/$file"
done
cp -R "$REPO_ROOT/src" "$PACK_ROOT/src"
if [[ -d "$REPO_ROOT/assets" ]]; then
  cp -R "$REPO_ROOT/assets" "$PACK_ROOT/assets"
fi

STAGED_OUTPUT="$STAGE_PARENT/adaptive_trainers-$VERSION.modpkg"
python3 "$ENGINE_ROOT/tools/modkit.py" --repo "$ENGINE_ROOT" \
  pack "$PACK_ROOT" --base fixture --output "$STAGED_OUTPUT"

mkdir -p "$REPO_ROOT/dist"
mv -f "$STAGED_OUTPUT" "$OUTPUT"

echo "$OUTPUT"
