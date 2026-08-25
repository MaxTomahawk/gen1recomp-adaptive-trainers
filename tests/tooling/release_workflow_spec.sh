#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
WORKFLOW="$REPO_ROOT/.github/workflows/release.yml"
ENGINE_SHA=08121faa3dd01ba68bb6bb74676650c5ebe1d116

if [[ ! -f "$WORKFLOW" ]]; then
  echo "release workflow is missing: .github/workflows/release.yml" >&2
  exit 1
fi

BODY=$(cat "$WORKFLOW")
for needle in \
  'tags: ["v*.*.*"]' \
  'contents: write' \
  "ref: $ENGINE_SHA" \
  'run: bash scripts/package.sh' \
  'adaptive_trainers-${VERSION}.zip' \
  'gh release create "$TAG"'; do
  if ! grep -Fq "$needle" <<<"$BODY"; then
    echo "release workflow is missing required contract: $needle" >&2
    exit 1
  fi
done

if grep -Fq 'git archive' <<<"$BODY"; then
  echo "release workflow must use the strict package scripts, not git archive" >&2
  exit 1
fi

if ! grep -Fq 'manifest version' <<<"$BODY"; then
  echo "release workflow must verify the tag matches manifest.json" >&2
  exit 1
fi

echo "release workflow contract checks passed"
