#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 OUTPUT" >&2
  exit 2
fi

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
ENGINE_ROOT=${GEN1RECOMP_ROOT:-"$REPO_ROOT/.engine/gen1recomp"}
OUTPUT=$1

if [[ -e "$OUTPUT" || -L "$OUTPUT" ]]; then
  echo "package_once.sh refuses to overwrite existing output: $OUTPUT" >&2
  exit 2
fi

if [[ ! -f "$ENGINE_ROOT/tools/modkit.py" || ! -f "$ENGINE_ROOT/tests/modkit/init.lua" ]]; then
  echo "GEN1RECOMP_ROOT is not a Gen1Recomp checkout: $ENGINE_ROOT" >&2
  exit 2
fi

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

OUTPUT_PARENT=$(dirname -- "$OUTPUT")
OUTPUT_NAME=$(basename -- "$OUTPUT")
mkdir -p "$OUTPUT_PARENT"
OUTPUT_PARENT=$(cd "$OUTPUT_PARENT" && pwd -P)
OUTPUT="$OUTPUT_PARENT/$OUTPUT_NAME"
if [[ -e "$OUTPUT" || -L "$OUTPUT" ]]; then
  echo "package_once.sh refuses to overwrite existing output: $OUTPUT" >&2
  exit 2
fi
python3 "$ENGINE_ROOT/tools/modkit.py" --repo "$ENGINE_ROOT" \
  pack "$PACK_ROOT" --base fixture --output "$OUTPUT"
