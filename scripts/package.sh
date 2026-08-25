#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
ENGINE_ROOT=${GEN1RECOMP_ROOT:-"$REPO_ROOT/.engine/gen1recomp"}

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

OUTPUT="$REPO_ROOT/dist/adaptive_trainers-$VERSION.zip"
DIST_PARENT="$REPO_ROOT/dist"
rm -f -- "$OUTPUT"
mkdir -p "$DIST_PARENT"

GEN1RECOMP_ROOT="$ENGINE_ROOT" "$REPO_ROOT/scripts/check.sh"

STAGE_PARENT=$(mktemp -d "$DIST_PARENT/.adaptive-trainers-package.XXXXXX")
PUBLISHED=0
cleanup() {
  local status=$?
  if [[ "$status" -ne 0 && "$PUBLISHED" -ne 1 ]]; then
    rm -f -- "$OUTPUT" || true
  fi
  if [[ "$STAGE_PARENT" == "$DIST_PARENT"/.adaptive-trainers-package.* ]]; then
    rm -rf -- "$STAGE_PARENT"
  fi
  return "$status"
}
trap cleanup EXIT

STAGED_OUTPUT="$STAGE_PARENT/adaptive_trainers-$VERSION.zip"
GEN1RECOMP_ROOT="$ENGINE_ROOT" SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" \
  "$REPO_ROOT/scripts/package_once.sh" "$STAGED_OUTPUT"

GEN1RECOMP_ROOT="$ENGINE_ROOT" SOURCE_DATE_EPOCH="$SOURCE_DATE_EPOCH" \
  PACKAGE_PATH="$STAGED_OUTPUT" bash "$REPO_ROOT/tests/tooling/package_layout_spec.sh"

mv -f "$STAGED_OUTPUT" "$OUTPUT"
PUBLISHED=1
echo "$OUTPUT"
