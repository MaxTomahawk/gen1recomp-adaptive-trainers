#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)
ENGINE_ROOT=${GEN1RECOMP_ROOT:-"$REPO_ROOT/.engine/gen1recomp"}

if [[ ! -f "$ENGINE_ROOT/tools/modkit.py" || ! -f "$ENGINE_ROOT/tests/modkit/init.lua" ]]; then
  echo "GEN1RECOMP_ROOT is not a Gen1Recomp checkout: $ENGINE_ROOT" >&2
  exit 2
fi

if ! command -v luajit >/dev/null 2>&1; then
  echo "LuaJIT is required to run Adaptive Trainers tests" >&2
  exit 2
fi

export ADAPTIVE_TRAINERS_ROOT="$REPO_ROOT"
export ADAPTIVE_TRAINERS_PATH
ADAPTIVE_TRAINERS_PATH=$(realpath --relative-to="$ENGINE_ROOT" "$REPO_ROOT")

mapfile -t LUA_TESTS < <(find "$REPO_ROOT/tests" -type f -name '*_spec.lua' | sort)
for test_file in "${LUA_TESTS[@]}"; do
  (
    cd "$ENGINE_ROOT"
    luajit "$test_file"
  )
done

python3 "$ENGINE_ROOT/tools/modkit.py" --repo "$ENGINE_ROOT" \
  validate "$REPO_ROOT" --base fixture
python3 "$ENGINE_ROOT/tools/modkit.py" --repo "$ENGINE_ROOT" \
  lint "$REPO_ROOT"

echo "Adaptive Trainers checks passed"
