#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
ENGINE_ROOT=${GEN1RECOMP_ROOT:?GEN1RECOMP_ROOT must name the audited engine checkout}
VERSION=$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$REPO_ROOT/manifest.json")
PACKAGE="$REPO_ROOT/dist/adaptive_trainers-$VERSION.modpkg"

if [[ ! -f "$PACKAGE" ]]; then
  echo "package layout test needs an initial package: $PACKAGE" >&2
  exit 2
fi

FIRST_SHA=$(sha256sum "$PACKAGE" | cut -d' ' -f1)
GEN1RECOMP_ROOT="$ENGINE_ROOT" SOURCE_DATE_EPOCH=0 \
  "$REPO_ROOT/scripts/package.sh" >/dev/null
SECOND_SHA=$(sha256sum "$PACKAGE" | cut -d' ' -f1)

if [[ "$FIRST_SHA" != "$SECOND_SHA" ]]; then
  echo "two packages from identical inputs are not byte-equivalent" >&2
  exit 1
fi

CONTENTS=$(unzip -Z1 "$PACKAGE")
if grep -Eq '^(dist|build|tests|scripts|docs)/|\.docx$' <<<"$CONTENTS"; then
  echo "package contains repository-only or recursive build content" >&2
  grep -E '^(dist|build|tests|scripts|docs)/|\.docx$' <<<"$CONTENTS" >&2
  exit 1
fi
for required in manifest.json mod.card main.lua src/core/rng.lua \
    src/data/line_meta.lua .modkit/pack.json; do
  if ! grep -Fxq "$required" <<<"$CONTENTS"; then
    echo "package is missing required file: $required" >&2
    exit 1
  fi
done

echo "package layout and reproducibility checks passed"
