#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)
FIXTURE=$(mktemp -d /tmp/adaptive-trainers-package-name.XXXXXX)
cleanup() {
  rm -rf -- "$FIXTURE"
}
trap cleanup EXIT

mkdir -p "$FIXTURE/scripts" "$FIXTURE/tests/tooling" "$FIXTURE/engine"
cp "$REPO_ROOT/scripts/package.sh" "$FIXTURE/scripts/package.sh"
printf '%s\n' '{"version":"0.1.0"}' > "$FIXTURE/manifest.json"

cat > "$FIXTURE/scripts/check.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$FIXTURE/scripts/package_once.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$(dirname -- "$1")"
: > "$1"
EOF
cat > "$FIXTURE/tests/tooling/package_layout_spec.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ -n "${PACKAGE_PATH:-}" ]]
[[ -f "$PACKAGE_PATH" ]]
EOF
chmod +x "$FIXTURE/scripts/check.sh" "$FIXTURE/scripts/package_once.sh" \
  "$FIXTURE/tests/tooling/package_layout_spec.sh"

OUTPUT=$(GEN1RECOMP_ROOT="$FIXTURE/engine" SOURCE_DATE_EPOCH=0 \
  bash "$FIXTURE/scripts/package.sh")
EXPECTED="$FIXTURE/dist/adaptive_trainers-0.1.0.zip"

if [[ "$OUTPUT" != "$EXPECTED" ]]; then
  echo "stable package must be named adaptive_trainers-0.1.0.zip" >&2
  echo "got: $OUTPUT" >&2
  exit 1
fi
if [[ ! -f "$EXPECTED" ]]; then
  echo "stable zip was not published at the expected path" >&2
  exit 1
fi
if [[ -e "$FIXTURE/dist/adaptive_trainers-0.1.0.modpkg" ]]; then
  echo "legacy .modpkg output must not be published by package.sh" >&2
  exit 1
fi

echo "stable zip package name contract passed"
