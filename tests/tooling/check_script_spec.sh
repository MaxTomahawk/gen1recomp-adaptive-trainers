#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
INVALID_ENGINE="$REPO_ROOT/.tmp/missing-engine"

set +e
OUTPUT=$(GEN1RECOMP_ROOT="$INVALID_ENGINE" "$REPO_ROOT/scripts/check.sh" 2>&1)
STATUS=$?
set -e

if [[ $STATUS -eq 0 ]]; then
  echo "expected scripts/check.sh to reject a missing engine checkout" >&2
  exit 1
fi

EXPECTED="GEN1RECOMP_ROOT is not a Gen1Recomp checkout: $INVALID_ENGINE"
if [[ "$OUTPUT" != *"$EXPECTED"* ]]; then
  echo "missing actionable engine-root diagnostic" >&2
  echo "$OUTPUT" >&2
  exit 1
fi

if ! grep -Fq 'tests/tooling/package_layout_spec.sh' "$REPO_ROOT/scripts/package.sh"; then
  echo "package.sh must invoke the package layout/reproducibility gate" >&2
  exit 1
fi

if ! grep -Fq 'PACKAGE_PATH=' "$REPO_ROOT/scripts/package.sh"; then
  echo "package.sh must pass the fresh package path to the layout gate" >&2
  exit 1
fi

if grep -Fq 'scripts/package.sh' "$REPO_ROOT/tests/tooling/package_layout_spec.sh"; then
  echo "package layout gate must use the non-recursive pack helper" >&2
  exit 1
fi

if grep -Fq 'dist/adaptive_trainers-' "$REPO_ROOT/tests/tooling/package_layout_spec.sh"; then
  echo "package layout gate must not infer a stale dist artifact" >&2
  exit 1
fi

bash "$REPO_ROOT/tests/tooling/release_package_name_spec.sh"

echo "check script contract passed"
