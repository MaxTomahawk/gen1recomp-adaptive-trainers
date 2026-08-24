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

STAGED_OUTPUT="$STAGE_PARENT/adaptive_trainers-$VERSION.modpkg"
GEN1RECOMP_ROOT="$ENGINE_ROOT" SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" \
  "$REPO_ROOT/scripts/package_once.sh" "$STAGED_OUTPUT"

mkdir -p "$REPO_ROOT/dist"
mv -f "$STAGED_OUTPUT" "$OUTPUT"

GEN1RECOMP_ROOT="$ENGINE_ROOT" SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" \
  PACKAGE_PATH="$OUTPUT" bash "$REPO_ROOT/tests/tooling/package_layout_spec.sh"

echo "$OUTPUT"
