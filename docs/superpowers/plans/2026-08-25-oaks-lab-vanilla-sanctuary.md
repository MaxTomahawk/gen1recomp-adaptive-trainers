# Oak's Lab Vanilla Sanctuary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the Oak's Lab starter Rival battle completely vanilla while preserving the observed result and starter continuity required by the later persistent Adaptive Rival journey.

**Architecture:** Treat `OAK_LAB` as a hard encounter-level bypass before any Adaptive party/moveset/AI transformation. Keep after-battle observation and Rival persistence. From `ROUTE_22_EARLY` onward, restore normal Adaptive Rival generation and tactical tier 3 under the world-progression legality rules from the companion plan.

**Tech Stack:** Lua, Gen1Recomp public trainer hooks/events, Adaptive Rival state, deterministic integration/property tests.

**Spec:** `docs/superpowers/specs/2026-08-25-progression-challenge-integrity-design.md`

## Global Constraints

- Oak's Lab must use the exact engine/vanilla Rival party, level, moves and battle AI for Red, Blue and Yellow.
- Do not replace tactical tier 3 with tactical tier 0/1 at Oak; bypass Adaptive battle transformation entirely.
- Adaptive Trainers may observe and persist the Oak result.
- Yellow Eevee outcome inference and Red/Blue starter continuity must remain correct.
- `ROUTE_22_EARLY` and every later Rival encounter remain adaptive.
- Do not use player move/species data for counter-selection.
- Do not change Brock/Aerodactyl or Gym species pools in this workstream.

---

## File Map

- `main.lua` — classifies active Rival encounters, hooks trainer party/AI/result lifecycle.
- `src/core/rival.lua` — persistent Rival journey state, starter ownership, encounter processing and result recording.
- `src/data/rival_windows.lua` — encounter IDs, version paths, Oak anchor and tactical tuning.
- `tests/integration/rival_version_paths_spec.lua` — Red/Blue/Yellow path integration.
- `tests/unit/rival_spec.lua` — persistent Rival state behavior.
- `tests/property/rival_fairness.lua` / `tests/property/rival_fairness_spec.lua` — anti-countering/fairness properties.
- `tests/acceptance/definition_of_done.lua` — aggregate release gate.
- `docs/BALANCING.md`, `docs/DEFINITION_OF_DONE_AUDIT.md`, `docs/IMPLEMENTATION_STATUS.md` — evidence only after tests are green.

---

### Task 1: Characterize every Oak transformation currently applied

**Files:**
- Modify: `tests/integration/rival_version_paths_spec.lua`
- Read: `main.lua`
- Read: `src/core/rival.lua`
- Read: `src/data/rival_windows.lua`

**Interfaces:**
- Consumes: vanilla trainer encounter context for `OAKS_LAB`, `OPP_RIVAL1`, version-specific party index.
- Produces: a failing regression that distinguishes vanilla Oak behavior from Adaptive Rival behavior.

- [ ] **Step 1: Add an Oak exact-parity fixture for Red/Blue**

Build a test that captures the vanilla party returned by the engine fixture before Adaptive hooks and compares it with the final party passed to battle.

For each Red/Blue starter path, assert:

```text
same species
same level
same ordered moves
same party length
no generated moveSources
no Adaptive party substitution
```

The test should use the actual fixture's vanilla move list rather than hard-coding a remembered external moveset when the fixture already exposes it.

- [ ] **Step 2: Add an Oak AI bypass assertion**

Instrument the mod test harness so the Oak battle does not receive the Rival expert/tactical context.

Expected conceptual assertion:

```lua
T.eq(active_boss_or_rival_context_for_oak, nil)
```

Use the harness's actual public-facing observation seam rather than reaching into locals with debug tricks.

- [ ] **Step 3: Add Yellow Oak parity coverage**

Assert Yellow's Oak encounter is likewise untouched while its result remains observable for later Eevee outcome inference.

- [ ] **Step 4: Run the focused integration test and verify RED**

```bash
GEN1RECOMP_ROOT=/path/to/gen1recomp lua tests/integration/rival_version_paths_spec.lua
```

Expected: at least one new Oak parity assertion fails on current v0.1.0 behavior for the intended reason.

- [ ] **Step 5: Commit the failing characterization**

```bash
git add tests/integration/rival_version_paths_spec.lua
git commit -m "test: characterize vanilla oak rival battle"
```

---

### Task 2: Introduce one explicit Oak transformation bypass

**Files:**
- Modify: `main.lua`
- Test: `tests/integration/rival_version_paths_spec.lua`

**Interfaces:**
- Consumes: Rival encounter classification from `rival_windows.for_battle(...)`.
- Produces: `OAK_LAB` as an encounter that is observed but never transformed.

- [ ] **Step 1: Add a small semantic helper near Rival encounter handling**

Use one named predicate instead of repeated map/class special-cases. Recommended shape:

```lua
local function rival_transform_enabled(encounterId)
  return encounterId ~= "OAK_LAB"
end
```

If an equivalent existing encounter-policy helper already exists when executing, extend that helper instead of duplicating logic.

- [ ] **Step 2: Gate Rival party transformation**

Where the mod would replace/generate the Rival party, require `rival_transform_enabled(encounterId)`.

Oak behavior must fall through to the original/next vanilla trainer-party implementation untouched.

- [ ] **Step 3: Gate Rival tactical AI context**

Where `active_boss_context` or its then-current equivalent identifies the active Rival and returns `RIVAL_PROFILE`, do not return the Adaptive profile for `OAK_LAB`.

Do not mutate the global Rival tuning from tier 3 to another tier; this is encounter-specific bypass, not retuning.

- [ ] **Step 4: Gate any Oak moveset generation path**

Search all calls that generate/refresh Rival moves around initial Oak build. Ensure the battle-facing Oak party cannot receive generated moves. Persistent state construction for future encounters may still initialize starter identity as long as it does not mutate the actual Oak battle party.

- [ ] **Step 5: Run the Oak parity integration test**

```bash
GEN1RECOMP_ROOT=/path/to/gen1recomp lua tests/integration/rival_version_paths_spec.lua
```

Expected: Oak parity assertions PASS; later Rival assertions may expose any state-continuity regression to fix in Task 3.

- [ ] **Step 6: Commit**

```bash
git add main.lua tests/integration/rival_version_paths_spec.lua
git commit -m "fix: keep oak rival battle vanilla"
```

---

### Task 3: Preserve Rival journey observation and continuity

**Files:**
- Modify: `src/core/rival.lua` only if tests prove state initialization currently depends on transformed Oak output.
- Modify: `tests/unit/rival_spec.lua`
- Modify: `tests/integration/rival_version_paths_spec.lua`

**Interfaces:**
- Consumes: vanilla Oak result and version/starter identity.
- Produces: later Adaptive Rival state identical in identity/history semantics to the approved design.

- [ ] **Step 1: Add Red/Blue continuity tests**

For each starter line, simulate:

```text
vanilla Oak battle observed
save/reload
Route 22 Early encounter
```

Assert the persistent Rival starter line/species path remains the correct canonical counter-starter and the Route 22 party is generated from the normal Adaptive anchor/window.

- [ ] **Step 2: Add Yellow outcome tests**

Cover at minimum:

```text
Oak loss -> Vaporeon branch basis
Oak win + Route 22 Early win -> Jolteon branch basis
Oak win + Route 22 Early loss/skip -> Flareon branch basis
```

The exact current `yellowRival` state fields must continue to be used; do not create a parallel result model.

- [ ] **Step 3: Prove result recording still occurs when transformation is bypassed**

The event/result handler should receive the Oak outcome even though party and AI hooks fell through to vanilla.

- [ ] **Step 4: Apply minimal state fix only if necessary**

If `src/core/rival.lua` assumes it built the Oak party before it can initialize the starter, decouple **persistent starter identity creation** from **battle transformation**. The persistent starter record may still use the Oak anchor as canonical journey history, but must not be injected into the live Oak battle.

- [ ] **Step 5: Run unit + integration tests**

```bash
GEN1RECOMP_ROOT=/path/to/gen1recomp lua tests/unit/rival_spec.lua
GEN1RECOMP_ROOT=/path/to/gen1recomp lua tests/integration/rival_version_paths_spec.lua
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/core/rival.lua tests/unit/rival_spec.lua tests/integration/rival_version_paths_spec.lua
git commit -m "fix: preserve rival journey after vanilla oak"
```

If production `src/core/rival.lua` did not need a change, omit it from the commit.

---

### Task 4: Prove tactical T3 begins at Route 22, not Oak

**Files:**
- Modify: `tests/integration/rival_version_paths_spec.lua`
- Modify: `tests/property/rival_fairness.lua`
- Read: `src/data/rival_windows.lua`
- Read: `src/data/ai_tiers.lua`

**Interfaces:**
- Consumes: encounter ID and Rival tactical profile.
- Produces: hard boundary `OAK_LAB = vanilla`, `ROUTE_22_EARLY+ = Adaptive tactical tier 3`.

- [ ] **Step 1: Add boundary assertions**

Test two consecutive encounters with the same save:

```text
OAK_LAB          -> no Adaptive tactical profile
ROUTE_22_EARLY   -> tactical tier 3 profile
```

Do not infer this from moves alone; assert the profile/context behavior.

- [ ] **Step 2: Preserve anti-countering property**

Run the Rival fairness property with level/time-equivalent player parties that vary species and move lists. The resulting Rival world/resource decisions must remain unchanged except where existing approved player-level pressure applies.

- [ ] **Step 3: Run property suite**

Use the repository's existing Rival property command or direct Lua invocation used by `tests/acceptance/definition_of_done.lua`.

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add tests/integration/rival_version_paths_spec.lua tests/property/rival_fairness.lua
git commit -m "test: bound rival tactics after oak"
```

---

### Task 5: Add aggregate acceptance and balancing evidence

**Files:**
- Modify: `tests/acceptance/definition_of_done.lua`
- Modify: `docs/BALANCING.md`
- Modify: `docs/DEFINITION_OF_DONE_AUDIT.md`
- Modify: `docs/IMPLEMENTATION_STATUS.md`

**Interfaces:**
- Consumes: completed Oak bypass and continuity behavior.
- Produces: release-blocking evidence.

- [ ] **Step 1: Add Oak vanilla acceptance to the aggregate**

The DoD aggregate must fail if any R/B/Y Oak starter battle is transformed by Adaptive Trainers.

- [ ] **Step 2: Record the balance decision precisely**

In `docs/BALANCING.md`, record:

```text
Oak's Lab is intentionally excluded from Adaptive tactical/moveset transformation.
This is not a reduction of the Rival's global tier; T3 begins at Route 22 Early.
```

- [ ] **Step 3: Run full mod gate**

```bash
GEN1RECOMP_ROOT=/path/to/gen1recomp ./scripts/check.sh
GEN1RECOMP_ROOT=/path/to/gen1recomp SOURCE_DATE_EPOCH=0 ./scripts/package.sh
git diff --check
git status --short
```

Expected: PASS and reproducible package.

- [ ] **Step 4: Real-game Blue/Yellow smoke acceptance**

Using legal private imports and public APIs only:

```text
Blue Oak: exact vanilla starter battle, no impossible TM
Blue Route 22: Adaptive Rival active
Yellow Oak: vanilla behavior
Yellow later path: outcome-dependent Eevee journey remains correct
```

Capture sanitized result only.

- [ ] **Step 5: Commit evidence**

```bash
git add tests/acceptance/definition_of_done.lua docs/BALANCING.md docs/DEFINITION_OF_DONE_AUDIT.md docs/IMPLEMENTATION_STATUS.md
git commit -m "docs: record oak vanilla rival evidence"
```

## Completion Gate

This workstream is complete only when Oak's battle is indistinguishable from no-mod vanilla behavior at the battle-facing party/moves/AI layer, while the later persistent Rival still observes Oak history and becomes fully Adaptive at Route 22 Early.