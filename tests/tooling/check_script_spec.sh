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

echo "check script contract passed"
