# Gym Battle Participation Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Gym registration a hard battle-local party contract so only registered Pokémon can participate, switch, replace, count toward exhaustion, receive battle traversal, or survive checkpoint restoration.

**Architecture:** Keep registration policy in the mod and battle participation authority in Gen1Recomp's existing `playerPartyIndices` public seam. First reproduce the observed Brock 3->2 leak on the exact released engine and current upstream. Fix the owning layer only; never mutate `game.save.party` as a workaround.

**Tech Stack:** Lua, Gen1Recomp mod hooks/UI facade, Gen1Recomp battle engine, shell test runners, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-25-progression-challenge-integrity-design.md`

## Global Constraints

- Registration uses the public `trainer.before_battle` continuation and `playerPartyIndices` contract.
- The full save party must remain unchanged before, during and after the Gym battle.
- Unregistered party members must be absent from initial send, voluntary switch, Shift prompt, forced replacement, exhaustion, EXP traversal, party-ball display and checkpoint restoration.
- When all registered Pokémon faint, the battle result is `lose` even if unregistered save-party members are healthy.
- Do not implement save-party deletion/reordering/replacement as a workaround.
- Before any engine branch/PR/update, fetch current `bryanthaboi/gen1recomp:dev` and reread current `CONTRIBUTING-mods.md`, relevant public API docs/RFC, CI and lint policy.
- Engine code must remain generic and must not contain Adaptive Trainers policy.
- Do not merge upstream PRs or rewrite shared history.

---

## File Map

**Adaptive Trainers**

- `main.lua` — owns Gym `trainer.before_battle` deferral and passes `playerPartyIndices`.
- `src/ui/gym_registration.lua` — owns selection UX and validation only.
- `tests/integration/gym_runtime_spec.lua` — primary mod-side runtime contract coverage.
- `tests/integration/gym_registration_spec.lua` — selection validation/UI semantics.
- `tests/property/gym_properties_spec.lua` — deterministic selection/fairness invariants.
- `tests/acceptance/definition_of_done.lua` — aggregate release gate.
- `docs/DEFINITION_OF_DONE_AUDIT.md` and `docs/IMPLEMENTATION_STATUS.md` — evidence ledger after behavior is proven.

**Gen1Recomp, only if ownership proves engine-side**

- `src/battle/BattleState.lua` — battle-local player-party view and all battle traversal consumers.
- `src/core/BattleCheckpoint.lua` — scoped party persistence/restoration if checkpoint behavior is implicated.
- `tests/engine/trainer_battle_party_scope.lua` — public contract regression suite.
- `tests/modkit/cases/trainer_before_battle.lua` — sandboxed public-hook behavior.
- current `docs/modding.md` and RFC for trainer battle party scope — contract docs.

If current upstream has moved the trainer encounter construction call site, locate it from the current `trainer.before_battle` implementation during Task 2 and record the exact current path in the engine commit/PR. Do not guess or cargo-cult a historical path.

---

### Task 1: Reproduce the Brock 3->2 leak at the mod boundary

**Files:**
- Modify: `tests/integration/gym_runtime_spec.lua`
- Read: `main.lua`
- Read: `src/ui/gym_registration.lua`

**Interfaces:**
- Consumes: `continueBattle({ playerPartyIndices = indices })` from `main.lua`.
- Produces: a deterministic regression fixture proving the selected indices passed by the mod are exactly the two the user chose.

- [ ] **Step 1: Add a failing regression named for the observed behavior**

Create a 3-member player party in the Gym runtime fixture, select non-contiguous indices such as `{1, 3}`, and capture the arguments passed to the deferred `continueBattle` callback.

The assertion must require:

```lua
T.same(continuation.playerPartyIndices, { 1, 3 })
T.eq(#save.party, 3)
```

Also assert `root.activeBoss.registeredIndices` is `{1, 3}`.

- [ ] **Step 2: Run the focused mod integration test**

Run:

```bash
GEN1RECOMP_ROOT=/path/to/gen1recomp lua tests/integration/gym_runtime_spec.lua
```

Expected result:

- If this fails because the mod passes the wrong/stale indices, ownership is mod-side. Continue to Task 3M.
- If this passes, record that the mod handoff is correct and continue to Task 2. Do not change production mod code merely to make the test look different.

- [ ] **Step 3: Commit only the characterization test if it exposes a mod bug**

If the test is already green, do not create a meaningless commit. Record the green evidence in the execution notes and continue.

---

### Task 2: Reproduce the full public contract on exact released engine and current upstream

**Files:**
- Modify: `tests/engine/trainer_battle_party_scope.lua` in an isolated Gen1Recomp branch only if missing coverage is required.
- Read: `src/battle/BattleState.lua`
- Read: `src/core/BattleCheckpoint.lua`
- Read: `tests/modkit/cases/trainer_before_battle.lua`
- Read: current `docs/modding.md` and trainer party-scope RFC.

**Interfaces:**
- Consumes: ordered one-based indices into `game.save.party`.
- Produces: a battle-local party view that is the sole player-party authority for the scoped trainer battle.

- [ ] **Step 1: Pin and test the released engine used by v0.1.0**

Use the released Gen1Recomp version required by the current manifest. Reproduce with a save party equivalent to:

```lua
local full = { mon("SQUIRTLE"), mon("CATERPIE"), mon("PIKACHU") }
local scope = { 1, 3 }
```

Construct a trainer battle through the same public hook/continuation path a mod uses, not by calling private internals that bypass engagement.

- [ ] **Step 2: Add/verify assertions for every authority path**

The engine test must prove all of these with `{1,3}`:

```text
initial send                -> only #1/#3
voluntary party menu        -> only #1/#3
Shift prompt                -> only #1/#3
forced replacement          -> only #1/#3
registered pair exhausted   -> battle loses
full save party             -> still contains #1/#2/#3
EXP participant traversal   -> excludes #2
party-ball display source   -> count 2
checkpoint restore          -> still only #1/#3
```

The test must specifically assert that healthy unregistered #2 does **not** prevent loss after #1 and #3 faint.

- [ ] **Step 3: Run the released-engine regression**

Run the repository's current focused command for `tests/engine/trainer_battle_party_scope.lua`, then full `./scripts/test.sh` if the focused test reproduces a failure.

Expected: the observed bug must fail somewhere in the contract before any production change is made.

- [ ] **Step 4: Repeat against current upstream `dev`**

Fetch current upstream and run the same scenario without carrying production patches across branches.

Record one of three outcomes:

```text
A. release fails, dev passes       -> dependency floor/release issue
B. release fails, dev fails        -> current upstream engine regression
C. release passes, mod repro fails -> integration/mod invocation issue
```

Do not proceed until ownership is unambiguous.

---

### Task 3M: Fix the mod only if Task 1 proves malformed/stale scope

**Files:**
- Modify: `main.lua`
- Test: `tests/integration/gym_runtime_spec.lua`
- Test: `tests/integration/gym_registration_spec.lua` if validation semantics change.

**Interfaces:**
- Consumes: validated selected save-party indices.
- Produces: exactly one `continueBattle({ playerPartyIndices = copy })` call with stable ordered indices.

- [ ] **Step 1: Keep the failing Task-1 regression red**

Do not weaken the expected `{1,3}` scope.

- [ ] **Step 2: Apply the smallest fix**

The implementation must:

```text
copy the selected indices
persist the same values in activeBoss.registeredIndices
call continuation once
never translate to zero-based indices
never translate selected display positions after the save party changes
```

No new battle enforcement code belongs in the mod.

- [ ] **Step 3: Run focused Gym tests**

```bash
GEN1RECOMP_ROOT=/path/to/gen1recomp lua tests/integration/gym_registration_spec.lua
GEN1RECOMP_ROOT=/path/to/gen1recomp lua tests/integration/gym_runtime_spec.lua
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add main.lua tests/integration/gym_runtime_spec.lua tests/integration/gym_registration_spec.lua
git commit -m "fix: preserve gym battle party scope"
```

Then skip Task 3E and continue to Task 4.

---

### Task 3E: Fix Gen1Recomp only if Task 2 proves the public engine contract is broken

**Files:**
- Modify: `src/battle/BattleState.lua` only where a consumer still references `game.save.party` instead of `self:playerPartyView()` or where the scoped view is lost.
- Modify: `src/core/BattleCheckpoint.lua` only if checkpoint capture/restore drops the scope.
- Modify current trainer-engagement call site only if Task 2 proves the continuation options never reach `BattleState.newTrainer`.
- Test: `tests/engine/trainer_battle_party_scope.lua`
- Test: `tests/modkit/cases/trainer_before_battle.lua` when hook handoff is implicated.
- Docs/RFC: update only if the public contract itself changes; a regression fix that restores documented behavior should not invent a new API.

**Interfaces:**
- Consumes: `opts.playerPartyIndices`.
- Produces: `BattleState:playerPartyView()` as the single scoped authority.

- [ ] **Step 1: Keep the failing engine regression red**

The failure must demonstrate the real leak, such as an unregistered mon visible in party menu or a healthy unregistered mon preventing blackout.

- [ ] **Step 2: Trace every full-party reference on the failing path**

Use repository search for `game.save.party`, `save.party`, `Party.firstHealthy`, party-menu construction, participant traversal and checkpoint restore within trainer-battle paths.

For each reference, classify:

```text
must use scoped view
intentionally full save party outside battle
not reached by trainer battle
```

Do not globally replace all save-party reads.

- [ ] **Step 3: Implement the smallest generic correction**

The preferred correction is to route the failing trainer-battle path through the already-documented accessor:

```lua
self:playerPartyView()
```

Do not add Gym, Leader, registration or Adaptive Trainers concepts to engine code.

- [ ] **Step 4: Run focused engine tests**

Run the current repository command for:

```text
tests/engine/trainer_battle_party_scope.lua
tests/modkit/cases/trainer_before_battle.lua
checkpoint tests if touched
```

Expected: all PASS.

- [ ] **Step 5: Run required engine gates**

Per current upstream policy, run:

```bash
./scripts/test.sh
./scripts/lint.sh --gate
./scripts/lint.sh
```

Also run the current no-mod parity and sandboxed public-API checks required by current policy.

- [ ] **Step 6: Commit the engine fix**

Use a concise generic subject such as:

```bash
git commit -m "fix(battle): preserve scoped trainer party through exhaustion"
```

Use the actual failing path in the subject/body if different.

- [ ] **Step 7: Open/update the upstream PR according to live policy**

The PR must identify Adaptive Trainers as the concrete consumer and the observed Brock 3->2 failure, while keeping the engine change generic. Include compatibility/no-mod evidence and all current Route-B obligations if current policy classifies the change that way.

Do not merge the PR.

---

### Task 4: Add end-to-end Adaptive Gym acceptance coverage

**Files:**
- Modify: `tests/integration/gym_runtime_spec.lua`
- Modify: `tests/acceptance/definition_of_done.lua`
- Modify: `docs/DEFINITION_OF_DONE_AUDIT.md`

**Interfaces:**
- Consumes: working public scoped-party engine contract.
- Produces: release-blocking mod acceptance evidence.

- [ ] **Step 1: Add the exact 3->2 scenario**

Fixture:

```text
save party: Squirtle, Caterpie, Pikachu
register: Squirtle + Pikachu
leader: Brock
```

Assertions must cover:

```text
registration shows max 2
continuation receives exactly two indices
battle party view has exactly two records
Caterpie cannot be selected by voluntary switch
Caterpie cannot be used as forced replacement
Squirtle+Pikachu both faint -> result lose
Caterpie remains healthy in save.party after loss
```

Do not assert which Brock flex species appears; Aerodactyl/Rhyhorn variation is explicitly out of scope.

- [ ] **Step 2: Add checkpoint scope acceptance**

Capture/resume mid-Gym battle and assert the same two indices remain authoritative.

- [ ] **Step 3: Add aggregate DoD invocation**

Ensure `tests/acceptance/definition_of_done.lua` executes the Gym participation integrity scenario.

- [ ] **Step 4: Run focused and aggregate gates**

```bash
GEN1RECOMP_ROOT=/path/to/gen1recomp lua tests/integration/gym_runtime_spec.lua
GEN1RECOMP_ROOT=/path/to/gen1recomp lua tests/acceptance/definition_of_done.lua
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/integration/gym_runtime_spec.lua tests/acceptance/definition_of_done.lua docs/DEFINITION_OF_DONE_AUDIT.md
git commit -m "test: enforce gym registered party scope"
```

---

### Task 5: Full regression and real-game verification

**Files:**
- Modify: `docs/IMPLEMENTATION_STATUS.md`
- Modify: `docs/DEFINITION_OF_DONE_AUDIT.md`
- No production changes unless a newly reproduced regression returns work to an earlier task.

**Interfaces:**
- Consumes: completed Gym scope implementation.
- Produces: sanitized release evidence.

- [ ] **Step 1: Run full mod gate**

```bash
GEN1RECOMP_ROOT=/path/to/gen1recomp ./scripts/check.sh
GEN1RECOMP_ROOT=/path/to/gen1recomp SOURCE_DATE_EPOCH=0 ./scripts/package.sh
git diff --check
git status --short
```

Expected: all green and package reproducible.

- [ ] **Step 2: Run released-engine/no-mod parity if engine changed or dependency floor changed**

Use exact engine SHA/tag and record it in the evidence ledger.

- [ ] **Step 3: Perform real Blue acceptance**

With a legal private Blue import and public APIs only:

```text
enter Brock with three healthy Pokémon
register two non-contiguous party members
verify the third never appears in switch/Shift/forced replacement
faint both registered members
verify immediate loss
verify third member remains healthy after battle
```

Capture only sanitized pass/fail, engine tag/SHA, mod commit and scenario name.

- [ ] **Step 4: Update evidence docs**

Record exact commands/results and whether ownership was mod-side, released-engine-only or upstream-engine.

- [ ] **Step 5: Commit documentation**

```bash
git add docs/IMPLEMENTATION_STATUS.md docs/DEFINITION_OF_DONE_AUDIT.md
git commit -m "docs: record gym participation integrity evidence"
```

## Completion Gate

This workstream is complete only when the observed 3->2 Brock case is impossible through every battle path and the full save party remains intact. A green registration UI test alone is insufficient.