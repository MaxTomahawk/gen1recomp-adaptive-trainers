# Progression Reachability & Evolution Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the World Progression Authority to non-level evolution resources, ecology traversal and organization-issued acquisition windows without forcing NPCs to mimic the player's exact collection route.

**Architecture:** Reuse the snapshot/provenance system created by the world-progression moveset plan. Add only the minimum new data required to answer whether an evolution method or acquisition source is plausible in the current world phase. Keep trainer identity exceptions explicit and preserve existing ecology/class behavior when no reliable story gate is known.

**Tech Stack:** Lua, existing Adaptive ecology/roster/stage resolver modules, Gen1Recomp public world/save data, deterministic property/integration tests.

**Spec:** `docs/superpowers/specs/2026-08-25-progression-challenge-integrity-design.md`

## Global Constraints

- This is P1 after Gym scope, Oak vanilla and TM/moveset progression workstreams.
- Reuse `src/core/world_progression.lua`; do not create a second progression authority.
- NPCs do not need to follow the player's exact species-acquisition timeline.
- Gym Leaders/experts may retain explicitly designed rare species.
- Brock's Aerodactyl/Rhyhorn flex pool is out of scope and must not be progression-gated by player acquisition rules.
- Surrogate levels remain useful for NPC non-level evolution timing but are no longer the only plausibility signal where a resource/method gate is reliable.
- Ecology must remain deterministic and based on public/canonical data.
- If a story barrier cannot be represented reliably from public data, prefer conservative existing behavior over invented hidden-state reads.
- Never read raw ROM/cache/private engine state.

---

## File Map

**Create**

- `src/data/evolution_progression.lua` — resource/method classes and world requirements for non-level NPC evolutions.
- `tests/unit/evolution_progression_spec.lua`
- `tests/property/reachability_properties_spec.lua`

**Modify**

- `src/core/world_progression.lua` — additional reusable area/gate queries only.
- `src/core/stage_resolver.lua` — optional evolution-legality context.
- `src/data/line_meta.lua` — explicit evolution policy metadata where surrogate-only inference is insufficient.
- `src/core/ecology.lua` — progression-aware neighbor traversal.
- `src/core/roster.lua` — pass progression context to catch/acquisition and stage resolution.
- `src/data/ecology_overrides.lua` — explicit organization/context windows rather than broad timeless issued pools.
- `src/core/standard_trainers.lua` — inject progression snapshot into ecology/roster/stage calls.
- `src/core/rival.lua` — use progression-aware acquisition windows only where approved Rival windows call for world resources.
- `src/core/bosses.lua`, `src/core/league_run.lua` — pass explicit boss exceptions so intended rare/special evolutions remain legal.
- `tests/unit/ecology_spec.lua`, `tests/unit/roster_spec.lua`, `tests/unit/generation_spec.lua`
- `tests/integration/phase_b_persistence_spec.lua`, `tests/integration/kanto_fallback_spec.lua`, `tests/integration/phase_g_runtime_spec.lua`
- `tests/acceptance/definition_of_done.lua`
- `docs/BALANCING.md`, `docs/DEFINITION_OF_DONE_AUDIT.md`, `docs/IMPLEMENTATION_STATUS.md`

---

### Task 1: Specify non-level evolution resource policy

**Files:**
- Create: `tests/unit/evolution_progression_spec.lua`
- Create: `src/data/evolution_progression.lua` after RED is observed.
- Read: `src/core/stage_resolver.lua`
- Read: `src/data/line_meta.lua`

**Interfaces:**
- Produces:

```lua
EvolutionProgression.for_transition(fromSpecies, toSpecies) -> rule|nil
EvolutionProgression.allowed(snapshot, trainerContext, rule) -> boolean, reason
```

Rule shape:

```lua
{
  method = "stone" | "trade" | "friendship" | "item_trade" | "special",
  availability = { kind = "world_stage", min = 3 },
  exceptionClass = nil | "boss" | "kanto_plus",
}
```

- [ ] **Step 1: Write RED tests for representative non-level transitions**

Cover at least:

```text
stone-style evolution
trade-style evolution
Kanto+ continuation
ordinary level evolution (no extra gate)
```

The tests must distinguish **timing** from **resource plausibility**.

- [ ] **Step 2: Preserve surrogate-level semantics in tests**

For a stone/trade line, assert both conditions are required for ordinary trainers:

```text
target level >= configured surrogate threshold
world/resource rule allowed
```

A lower level remains illegal even when the resource exists; a high level remains unavailable before the world/resource rule unless an explicit trainer exception exists.

- [ ] **Step 3: Add boss exception test**

An explicit boss/Kanto+ exception can authorize a designed special evolution without using the player's personal resource state.

- [ ] **Step 4: Verify RED**

```bash
lua tests/unit/evolution_progression_spec.lua
```

Expected: FAIL because the module/context does not exist.

- [ ] **Step 5: Commit test**

```bash
git add tests/unit/evolution_progression_spec.lua
git commit -m "test: define npc evolution progression policy"
```

---

### Task 2: Implement evolution progression data and stage-resolver context

**Files:**
- Create: `src/data/evolution_progression.lua`
- Modify: `src/core/stage_resolver.lua`
- Modify: `src/data/line_meta.lua`
- Modify: `tests/unit/evolution_progression_spec.lua`
- Modify: `tests/unit/generation_spec.lua`

**Interfaces:**
- Consumes: line metadata, target level, world snapshot, trainer context.
- Produces: species stage only when both level/surrogate and resource policy allow it.

Recommended optional context:

```lua
{
  progression = snapshot,
  evolutionProgression = EvolutionProgression,
  trainer = { kind = "standard", classId = "OPP_LASS", identity = "..." },
  exceptions = { STEELIX = "kanto_plus" },
}
```

Recommended signature extension:

```lua
stage_resolver.resolve(line, targetLevel, pokemon, preferredSpecies, context)
```

- [ ] **Step 1: Keep ordinary level evolutions unchanged**

If a transition is naturally level-based in the runtime registry, no additional world-resource rule is required unless explicitly configured.

- [ ] **Step 2: Gate configured non-level/surrogate transitions**

When a line stage uses a surrogate because no level evolution exists, consult `EvolutionProgression` before selecting the stage.

- [ ] **Step 3: Keep missing/unknown method conservative**

If the line explicitly requires progression metadata and none exists, do not guess the final evolution; return the highest earlier legal stage.

- [ ] **Step 4: Support explicit boss/Kanto+ exceptions**

Exceptions must be passed in by the caller/data, not inferred from trainer power or player inventory.

- [ ] **Step 5: Run focused tests**

```bash
lua tests/unit/evolution_progression_spec.lua
lua tests/unit/generation_spec.lua
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/data/evolution_progression.lua src/core/stage_resolver.lua src/data/line_meta.lua tests/unit/evolution_progression_spec.lua tests/unit/generation_spec.lua
git commit -m "feat: gate npc non-level evolutions by world progression"
```

---

### Task 3: Thread evolution context through trainer generation and growth

**Files:**
- Modify: `src/core/standard_trainers.lua`
- Modify: `src/core/growth.lua`
- Modify: `src/core/roster.lua`
- Modify: `src/core/rival.lua`
- Modify: `src/core/bosses.lua`
- Modify: `src/core/league_run.lua`
- Modify: `main.lua`
- Modify: `tests/integration/phase_b_persistence_spec.lua`
- Modify: `tests/integration/phase_g_runtime_spec.lua`

**Interfaces:**
- Consumes: one world snapshot per encounter/materialization boundary.
- Produces: every stage-resolution path with explicit context.

- [ ] **Step 1: Standard trainers**

Pass ordinary trainer context through initial generation, catches and growth evolution.

- [ ] **Step 2: Rival**

Use world progression for ordinary non-level evolution plausibility from Route 22 onward. Preserve canonical Rival path rules and explicit designed anchors.

- [ ] **Step 3: Boss/League**

Pass identity exceptions where the approved boss roster intentionally uses a special stage. Do not derive exceptions from the player's collection timeline.

- [ ] **Step 4: Kanto+**

Pass Kanto+ continuation exceptions only when the existing Kanto+ capability is enabled. The Kanto-only fallback must remain unchanged when Gold data is absent.

- [ ] **Step 5: Run integration tests**

```bash
lua tests/integration/phase_b_persistence_spec.lua
lua tests/integration/phase_g_runtime_spec.lua
lua tests/integration/kanto_fallback_spec.lua
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/core/standard_trainers.lua src/core/growth.lua src/core/roster.lua src/core/rival.lua src/core/bosses.lua src/core/league_run.lua main.lua tests/integration/phase_b_persistence_spec.lua tests/integration/phase_g_runtime_spec.lua tests/integration/kanto_fallback_spec.lua
git commit -m "feat: apply progression to npc evolution paths"
```

---

### Task 4: Define progression-aware ecology reachability

**Files:**
- Create: `tests/property/reachability_properties_spec.lua`
- Modify: `tests/unit/ecology_spec.lua`
- Read: `src/core/ecology.lua`
- Read: `src/data/world_progression.lua`

**Interfaces:**
- Produces:

```lua
WorldProgression.can_traverse(snapshot, fromMapId, toMapId, edgeContext) -> boolean, reason
```

- [ ] **Step 1: Write RED property for barrier monotonicity**

A route blocked at stage `S` must not become blocked after progression advances to `S+1`.

- [ ] **Step 2: Write RED ecology leak fixture**

Construct two maps that are graph-adjacent but whose connecting edge is marked with a world gate. Assert ecology at the early side cannot source encounters from the far side before the gate.

- [ ] **Step 3: Write post-unlock fixture**

After the corresponding milestone/stage, the same adjacency can participate in normal radius weighting.

- [ ] **Step 4: Add unknown-edge fallback property**

An edge without a known progression gate preserves current behavior. Do not invent a lock from map names.

- [ ] **Step 5: Verify RED**

```bash
lua tests/unit/ecology_spec.lua
lua tests/property/reachability_properties_spec.lua
```

Expected: FAIL on gated-edge behavior.

- [ ] **Step 6: Commit tests**

```bash
git add tests/unit/ecology_spec.lua tests/property/reachability_properties_spec.lua
git commit -m "test: define progression-aware ecology reachability"
```

---

### Task 5: Implement gated ecology traversal

**Files:**
- Modify: `src/data/world_progression.lua`
- Modify: `src/core/world_progression.lua`
- Modify: `src/core/ecology.lua`
- Modify: `src/core/standard_trainers.lua`
- Modify: `tests/unit/ecology_spec.lua`
- Modify: `tests/property/reachability_properties_spec.lua`

**Interfaces:**
- Consumes: map adjacency + progression snapshot.
- Produces: same current ecology weighting on allowed edges, zero traversal across known locked edges.

- [ ] **Step 1: Add explicit gate metadata**

Use data keyed by directed/undirected map-edge identifiers or area transitions, for example:

```lua
edgeGates = {
  ["AREA_A>AREA_B"] = { kind = "world_stage", min = 4 },
}
```

Use real current map IDs during implementation. Do not infer gates from human-readable map-name fragments.

- [ ] **Step 2: Extend neighbor traversal**

`ecology.resolve` should accept a progression context and call `can_traverse` before enqueueing a known gated neighbor.

- [ ] **Step 3: Preserve local encounters**

If the current map has local eligible encounters, existing behavior returns local rows immediately; progression gating should not alter them.

- [ ] **Step 4: Preserve deterministic distance weights**

Allowed paths retain the current distance weighting (`1.0`, `0.55`, `0.25`). Do not rebalance rarity/weight in this task.

- [ ] **Step 5: Run focused tests**

```bash
lua tests/unit/ecology_spec.lua
lua tests/property/reachability_properties_spec.lua
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/data/world_progression.lua src/core/world_progression.lua src/core/ecology.lua src/core/standard_trainers.lua tests/unit/ecology_spec.lua tests/property/reachability_properties_spec.lua
git commit -m "feat: gate trainer ecology by world reachability"
```

---

### Task 6: Replace timeless organization-issued pools with progression windows

**Files:**
- Modify: `src/data/ecology_overrides.lua`
- Modify: `src/core/ecology.lua`
- Modify: `src/core/roster.lua`
- Modify: `tests/unit/ecology_spec.lua`
- Modify: `tests/unit/roster_spec.lua`
- Modify: `tests/integration/phase_b_persistence_spec.lua`

**Interfaces:**
- Consumes: class/context issue policy + progression snapshot + current trainer party index/identity.
- Produces: organization-issued candidate pool restricted to plausible current windows.

- [ ] **Step 1: Add RED early/late Rocket fixtures**

An early Rocket must not inherit every later Rocket-issued species merely because later trainer parties exist in the dataset. A later Rocket can access the expanded configured organization window.

- [ ] **Step 2: Replace boolean override with explicit policy**

Evolve data such as:

```lua
OPP_ROCKET = {
  mode = "organization_issued",
  windows = {
    { maxStage = 2, partyIndexMax = 5 },
    { maxStage = 5, partyIndexMax = 20 },
    { maxStage = 9, partyIndexMax = math.huge },
  },
}
```

Use actual tested boundaries derived from the trainer dataset and approved plausibility review; do not use these example numbers blindly.

- [ ] **Step 3: Keep Scientist/Super Nerd context semantics explicit**

If their issued pools should be based on laboratory/context rather than organization progression, model separate `mode` values instead of overloading Rocket windows.

- [ ] **Step 4: Keep unique/static species excluded**

Existing `populationModel` hard exclusions remain authoritative unless a specific issued override intentionally names a species.

- [ ] **Step 5: Run focused tests**

```bash
lua tests/unit/ecology_spec.lua
lua tests/unit/roster_spec.lua
lua tests/integration/phase_b_persistence_spec.lua
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/data/ecology_overrides.lua src/core/ecology.lua src/core/roster.lua tests/unit/ecology_spec.lua tests/unit/roster_spec.lua tests/integration/phase_b_persistence_spec.lua
git commit -m "feat: stage organization trainer acquisitions"
```

---

### Task 7: Validate that identity exceptions remain identity exceptions

**Files:**
- Modify: `tests/unit/bosses_spec.lua`
- Modify: `tests/integration/gym_runtime_spec.lua`
- Modify: `tests/integration/phase_g_runtime_spec.lua`
- Modify: `tests/property/reachability_properties_spec.lua`

**Interfaces:**
- Consumes: boss/rare species data and progression gates.
- Produces: proof that world progression does not become a universal player-acquisition simulator.

- [ ] **Step 1: Add a boss-species non-goal regression**

Assert a boss flex species explicitly present in the approved boss pool is not rejected solely because the player has not reached that species' ordinary acquisition source.

Use a stable test identity; do not create a special Aerodactyl restriction test. The invariant is generic: **boss pool membership is an identity authority unless another explicit boss rule says otherwise.**

- [ ] **Step 2: Add ordinary-trainer contrast**

An ordinary trainer acquisition sourced through ecology must still obey reachability.

- [ ] **Step 3: Add Kanto+ contrast**

Kanto+ special species/evolutions remain unavailable when capability is off and available when the existing explicit capability/identity rule permits them.

- [ ] **Step 4: Run tests**

```bash
lua tests/unit/bosses_spec.lua
lua tests/integration/gym_runtime_spec.lua
lua tests/integration/phase_g_runtime_spec.lua
lua tests/property/reachability_properties_spec.lua
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tests/unit/bosses_spec.lua tests/integration/gym_runtime_spec.lua tests/integration/phase_g_runtime_spec.lua tests/property/reachability_properties_spec.lua
git commit -m "test: preserve trainer identity progression exceptions"
```

---

### Task 8: Full simulation and acceptance

**Files:**
- Modify: `tests/acceptance/definition_of_done.lua`
- Modify: `docs/BALANCING.md`
- Modify: `docs/DEFINITION_OF_DONE_AUDIT.md`
- Modify: `docs/IMPLEMENTATION_STATUS.md`

**Interfaces:**
- Consumes: completed reachability/evolution work.
- Produces: P1 completion evidence.

- [ ] **Step 1: Add aggregate properties**

Require:

```text
non-level evolution needs timing + resource plausibility
known locked ecology edge blocks remote candidates
same edge unlocks monotonically
unknown edges preserve current behavior
organization pools expand monotonically by configured windows
boss species identity remains independent of player acquisition path
Kanto-only fallback remains unchanged
```

- [ ] **Step 2: Re-run balance/property simulations**

Compare catch candidate counts and line distributions before/after known gate changes. Record meaningful differences in `docs/BALANCING.md`.

- [ ] **Step 3: Run full project gates**

```bash
GEN1RECOMP_ROOT=/path/to/gen1recomp ./scripts/check.sh
GEN1RECOMP_ROOT=/path/to/gen1recomp SOURCE_DATE_EPOCH=0 ./scripts/package.sh
git diff --check
git status --short
```

Expected: PASS.

- [ ] **Step 4: Real Blue + Gold acceptance**

Add sanitized scenarios around:

```text
early ordinary trainer ecology
post-gate ordinary trainer ecology
non-level NPC evolution before/after resource stage
boss rare-species identity unaffected
Kanto+ continuation still capability-gated
save/reload monotonic progression
```

- [ ] **Step 5: Commit evidence**

```bash
git add tests/acceptance/definition_of_done.lua docs/BALANCING.md docs/DEFINITION_OF_DONE_AUDIT.md docs/IMPLEMENTATION_STATUS.md
git commit -m "docs: record progression reachability evidence"
```

## Completion Gate

This workstream is complete when known world barriers constrain ordinary ecology and non-level evolution plausibility without turning NPCs into copies of the player's acquisition path, and when trainer identity/Kanto+ exceptions remain explicit, deterministic and reviewable.