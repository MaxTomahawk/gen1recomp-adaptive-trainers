#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
ENGINE_ROOT=${GEN1RECOMP_ROOT:?GEN1RECOMP_ROOT must name the audited engine checkout}
TEST_PARENT=$(mktemp -d /tmp/adaptive-trainers-package-helper.XXXXXX)
cleanup() {
  if [[ "$TEST_PARENT" == /tmp/adaptive-trainers-package-helper.* ]]; then
    rm -rf -- "$TEST_PARENT"
  fi
}
trap cleanup EXIT

SENTINEL="$TEST_PARENT/sentinel.bin"
printf 'do not overwrite this sentinel\n' > "$SENTINEL"

EXISTING="$TEST_PARENT/existing.modpkg"
cp "$SENTINEL" "$EXISTING"
set +e
GEN1RECOMP_ROOT="$ENGINE_ROOT" SOURCE_DATE_EPOCH=0 \
  "$REPO_ROOT/scripts/package_once.sh" "$EXISTING" \
  > "$TEST_PARENT/existing.log" 2>&1
STATUS=$?
set -e
if [[ $STATUS -eq 0 ]]; then
  echo "package_once.sh must reject an existing regular output" >&2
  exit 1
fi
if ! cmp -s "$SENTINEL" "$EXISTING"; then
  echo "existing regular output was modified" >&2
  exit 1
fi

SYMLINK="$TEST_PARENT/existing-link.modpkg"
ln -s "$(basename "$SENTINEL")" "$SYMLINK"
set +e
GEN1RECOMP_ROOT="$ENGINE_ROOT" SOURCE_DATE_EPOCH=0 \
  "$REPO_ROOT/scripts/package_once.sh" "$SYMLINK" \
  > "$TEST_PARENT/symlink.log" 2>&1
STATUS=$?
set -e
if [[ $STATUS -eq 0 ]]; then
  echo "package_once.sh must reject an existing symlink output" >&2
  exit 1
fi
if [[ ! -L "$SYMLINK" ]] || ! cmp -s "$SENTINEL" "$SYMLINK"; then
  echo "existing symlink output or its target was modified" >&2
  exit 1
fi

echo "package helper rejects existing files and symlinks"
