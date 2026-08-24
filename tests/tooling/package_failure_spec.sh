#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
ENGINE_ROOT=${GEN1RECOMP_ROOT:?GEN1RECOMP_ROOT must name the audited engine checkout}
VERSION=$(sed -n 's/^[[:space:]]*"version":[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$REPO_ROOT/manifest.json")
OUTPUT="$REPO_ROOT/dist/adaptive_trainers-$VERSION.modpkg"
TEST_PARENT=$(mktemp -d /tmp/adaptive-trainers-package-failure.XXXXXX)
cleanup() {
  if [[ "$TEST_PARENT" == /tmp/adaptive-trainers-package-failure.* ]]; then
    rm -rf -- "$TEST_PARENT"
  fi
  rm -f -- "$OUTPUT"
}
trap cleanup EXIT

mkdir -p "$REPO_ROOT/dist"
printf 'stale package must not survive a failed replacement\n' > "$OUTPUT"
cat > "$TEST_PARENT/luajit" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$TEST_PARENT/luajit"
cat > "$TEST_PARENT/unzip" <<'EOF'
#!/usr/bin/env bash
echo "forced package layout failure" >&2
exit 91
EOF
chmod +x "$TEST_PARENT/unzip"

set +e
PATH="$TEST_PARENT:$PATH" MODKIT_LUAJIT="$TEST_PARENT/luajit" \
  GEN1RECOMP_ROOT="$ENGINE_ROOT" SOURCE_DATE_EPOCH=0 \
  "$REPO_ROOT/scripts/package.sh" > "$TEST_PARENT/package.log" 2>&1
STATUS=$?
set -e

if [[ $STATUS -eq 0 ]]; then
  echo "expected package.sh to fail when layout verification fails" >&2
  exit 1
fi
if [[ -e "$OUTPUT" ]]; then
  echo "failed package gate left a public package artifact: $OUTPUT" >&2
  exit 1
fi

echo "failed package gate leaves no public artifact"
