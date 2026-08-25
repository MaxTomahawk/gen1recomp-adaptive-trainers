# World Progression & Moveset Integrity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce a single world-progression authority that gates TM/HM and boss-technique resources, separates tactical AI from moveset sophistication, refreshes persistent trainers only when progression advances, and migrates v0.1.0 state without resetting trainer history.

**Architecture:** Add pure progression/provenance modules, then thread a read-only legality context into the existing moveset generator. Keep tactical intelligence, moveset optimization and world-resource availability as separate axes. Bosses may use explicit identity/Kanto+ exceptions; ordinary trainers never gain a move merely because the species registry says it is TM/HM compatible.

**Tech Stack:** Lua, Gen1Recomp public save/events/content registries, deterministic unit/property/integration tests, existing strict package tooling.

**Spec:** `docs/superpowers/specs/2026-08-25-progression-challenge-integrity-design.md`

## Global Constraints

- Use the approved hybrid model: ordinary/repeatable resources unlock by world accessibility; unique Gym/story rewards unlock generically only after their milestone.
- The canonical owner/awarder may use an explicit identity-scoped exception before generic unlock.
- Never key NPC move legality to whether the player personally owns, picked up, bought or taught the move.
- Player species and move lists must not affect resource availability or candidate selection.
- `tacticalTier` and `movesetTier` are distinct concepts.
- Generated TM/HM candidates require provenance; unknown machine provenance is rejected, not silently accepted.
- Existing legal level-up/vanilla/inherited moves survive migration.
- Progression is monotone for trainer-resource purposes.
- Do not build a full NPC inventory/economy simulator.
- Do not add player-style species acquisition gates to Gym Leaders; Brock/Aerodactyl is explicitly out of scope.
- Kanto+ remains capability-gated and explicit.

---

## File Map

**Create**

- `src/core/world_progression.lua` — normalize progression snapshots and answer resource/milestone queries.
- `src/data/world_progression.lua` — version-aware milestone/area ordering and conservative mid-save fallbacks.
- `src/data/tm_progression.lua` — complete Gen-I TM/HM provenance metadata used by the mod.
- `tests/unit/world_progression_spec.lua` — pure progression query tests.
- `tests/unit/tm_progression_spec.lua` — complete provenance-table validation.
- `tests/property/progression_properties_spec.lua` — monotonicity, anti-spying and determinism properties.

**Modify**

- `src/core/movesets.lua` — filter machine candidates by provenance/context and persist richer move source metadata.
- `src/data/move_packages.lua` — keep moveset scoring/tier constants; rename semantics only where needed.
- `src/data/trainer_profiles.lua` — separate `tacticalTier` and `movesetTier`.
- `src/data/rival_windows.lua` — separate Rival tactical/moveset tiers while keeping Route-22+ tactical T3.
- `src/core/ai.lua` — consume tactical tier only.
- `src/core/standard_trainers.lua` — pass moveset tier + progression legality context.
- `src/core/growth.lua` — progression-aware refresh and moveset tier.
- `src/core/bosses.lua` — pass boss exceptions/provenance context.
- `src/core/league_run.lua` — pass League exceptions/provenance context.
- `src/core/rival.lua` and/or the Rival assembly call site in `main.lua` — pass progression legality context for post-Oak Rival movesets.
- `src/core/save_schema.lua` — schema migration for progression epoch/provenance version.
- `main.lua` — construct progression snapshot from public save/world state, observe map progression, and inject contexts.
- `src/core/diagnostics.lua`, `src/ui/debug.lua` — sanitized provenance/rejection evidence.
- `tests/unit/movesets_spec.lua`, `tests/unit/ai_spec.lua`, `tests/unit/growth_spec.lua`, `tests/unit/save_schema_spec.lua`
- `tests/integration/phase_c_moves_ai_spec.lua`, `tests/integration/phase_b_persistence_spec.lua`, `tests/integration/rival_version_paths_spec.lua`, `tests/integration/gym_runtime_spec.lua`, `tests/integration/league_persistence_spec.lua`
- `tests/acceptance/definition_of_done.lua`
- `docs/BALANCING.md`, `docs/DEFINITION_OF_DONE_AUDIT.md`, `docs/IMPLEMENTATION_STATUS.md`

---

### Task 1: Define progression and provenance contracts with failing tests

**Files:**
- Create: `tests/unit/world_progression_spec.lua`
- Create: `tests/unit/tm_progression_spec.lua`
- Create: `tests/property/progression_properties_spec.lua`
- Read: `src/core/player_power.lua`
- Read: current public Gen1Recomp save/event docs before implementing adapters.

**Interfaces:**
- Produces: exact contracts later tasks must implement.

Define these interfaces in tests before production code:

```lua
WorldProgression.snapshot(save, data, persisted) -> snapshot
WorldProgression.resource_available(snapshot, rule) -> boolean, reason
WorldProgression.advance(persisted, snapshot) -> changed, epoch
TmProgression.for_move(moveId, version) -> provenance|nil
TmProgression.machine_moves(version) -> sorted move ids
```

Normalized snapshot shape:

```lua
{
  version = "blue",
  badgeCount = 0,
  milestones = {},
  reachedAreas = {},
  worldStage = 0,
  epoch = 0,
}
```

- [ ] **Step 1: Write RED tests for monotone world progression**

Cover:

```text
same save/state -> same snapshot
adding a badge cannot reduce stage/epoch
adding a reached area cannot reduce stage/epoch
save/load with identical authority cannot increment epoch
player species/moves do not change snapshot
```

- [ ] **Step 2: Write RED tests for resource rules**

At minimum define rule kinds:

```lua
{ kind = "always" }
{ kind = "world_stage", min = 3 }
{ kind = "area_reached", id = "CELADON_CITY", fallbackStage = 3 }
{ kind = "milestone", id = "LT_SURGE_DEFEATED" }
{ kind = "identity_exception", id = "LT_SURGE" }
```

`resource_available` must return stable reason strings such as:

```text
available
world-stage-too-early
area-not-reached
milestone-incomplete
identity-exception-required
```

- [ ] **Step 3: Write RED completeness tests for machine provenance**

The provenance table must cover every TM/HM move that can appear through Gen-I species `tmhm` compatibility in the released engine dataset used by tests. Unknown machine moves must make the test fail with the move ID.

Do not copy ROM bytes/text; only store factual identifiers and abstract progression metadata.

- [ ] **Step 4: Add representative semantic assertions**

Use known Gym reward identities as hard checks:

```text
Brock reward technique -> generic availability only after Brock milestone
Misty reward technique -> generic availability only after Misty milestone
Lt. Surge reward technique -> generic availability only after Surge milestone
owner identity exception -> owner may use its configured signature before milestone
```

Also assert `SOLARBEAM` is not machine-legal at world stage `0` / Oak context.

- [ ] **Step 5: Run and verify RED**

```bash
lua tests/unit/world_progression_spec.lua
lua tests/unit/tm_progression_spec.lua
lua tests/property/progression_properties_spec.lua
```

Expected: FAIL because modules do not exist.

- [ ] **Step 6: Commit tests**

```bash
git add tests/unit/world_progression_spec.lua tests/unit/tm_progression_spec.lua tests/property/progression_properties_spec.lua
git commit -m "test: define trainer world progression contract"
```

---

### Task 2: Implement the World Progression Authority

**Files:**
- Create: `src/data/world_progression.lua`
- Create: `src/core/world_progression.lua`
- Modify: `src/core/save_schema.lua`
- Modify: `tests/unit/world_progression_spec.lua`
- Modify: `tests/unit/save_schema_spec.lua`

**Interfaces:**
- Consumes: public save version/badge/story information plus persisted reached-area observations.
- Produces: immutable-like normalized snapshot and monotone epoch.

- [ ] **Step 1: Define version-aware stage data**

`src/data/world_progression.lua` should contain explicit ordered stage IDs rather than magic badge thresholds spread through code. Recommended structure:

```lua
return {
  version = 1,
  stages = {
    "PALLET_START",
    "PEWTER",
    "CERULEAN",
    "VERMILION",
    "CELADON_LAVENDER",
    "FUCHSIA_SAFFRON",
    "CINNABAR",
    "VIRIDIAN_GYM",
    "INDIGO",
    "POSTGAME",
  },
  badgeMilestones = {
    -- explicit badge/leader mapping by public IDs, version-aware if needed
  },
  areaStages = {
    -- map/area ID -> earliest conservative stage
  },
}
```

Use current public dataset identifiers, not remembered display strings. Red/Blue/Yellow differences must be represented where the source order differs.

- [ ] **Step 2: Implement `snapshot` as a pure normalization function**

Recommended signature:

```lua
function M.snapshot(save, data, persisted)
  return {
    version = normalized_version,
    badgeCount = badge_count,
    milestones = inferred_and_persisted_milestones,
    reachedAreas = copied_persisted_areas,
    worldStage = stage,
    epoch = persisted_epoch_or_derived,
  }
end
```

Use public badge/save structures and current data constants. Merge authoritative current facts into persisted facts; never delete previously observed milestones/areas.

- [ ] **Step 3: Implement stable availability reasons**

`resource_available(snapshot, rule, context)` may accept an optional context only for explicit identity exceptions; it must never inspect player roster/moves.

- [ ] **Step 4: Add schema state**

Under the existing root, add one focused progression record, for example:

```lua
root.progression = {
  version = 1,
  epoch = 0,
  reachedAreas = {},
  milestones = {},
}
```

Migration must create this record without changing existing trainer/Rival/boss state.

- [ ] **Step 5: Make `advance` monotone and idempotent**

Increment epoch exactly once when the set of world-resource-relevant facts grows. Re-loading the same save must not increment it.

- [ ] **Step 6: Run unit/schema tests**

```bash
lua tests/unit/world_progression_spec.lua
lua tests/unit/save_schema_spec.lua
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add src/data/world_progression.lua src/core/world_progression.lua src/core/save_schema.lua tests/unit/world_progression_spec.lua tests/unit/save_schema_spec.lua
git commit -m "feat: add trainer world progression authority"
```

---

### Task 3: Build complete TM/HM provenance data

**Files:**
- Create: `src/data/tm_progression.lua`
- Modify: `tests/unit/tm_progression_spec.lua`
- Read: released engine public Pokémon/move/item datasets and canonical vanilla progression references during implementation.

**Interfaces:**
- Consumes: move ID + game version.
- Produces: deterministic machine/source provenance.

Provenance record contract:

```lua
{
  moveId = "THUNDERBOLT",
  machine = "TM24",
  class = "gym_reward",
  sourceId = "LT_SURGE_REWARD",
  availability = { kind = "milestone", id = "LT_SURGE_DEFEATED" },
}
```

- [ ] **Step 1: Enumerate every Gen-I TM and HM used by species compatibility**

Build the table from authoritative current public/canonical references. Store only identifiers and progression facts.

Each record must use one class:

```text
store_repeatable
field_pickup
limited_pickup
gym_reward
story_reward
hm
```

Identity/Kanto+ exceptions belong to trainer/boss package data, not the base machine table.

- [ ] **Step 2: Model ordinary field/store availability**

Use `area_reached` plus `fallbackStage` where practical so new playthroughs use precise observed reachability while mid-save installs have a conservative deterministic fallback.

- [ ] **Step 3: Model unique Gym/story rewards**

Use explicit milestone rules. Generic trainers do not gain them before the milestone.

- [ ] **Step 4: Add version differences explicitly**

If a TM/HM source differs in Red/Blue/Yellow, use version-specific records instead of a lowest-common-denominator unlock.

- [ ] **Step 5: Make completeness tests green**

```bash
lua tests/unit/tm_progression_spec.lua
```

Expected: every machine-compatible move in the test dataset resolves to exactly one applicable provenance record per supported version.

- [ ] **Step 6: Commit**

```bash
git add src/data/tm_progression.lua tests/unit/tm_progression_spec.lua
git commit -m "feat: map vanilla machine progression"
```

---

### Task 4: Gate the moveset legal pool by provenance

**Files:**
- Modify: `src/core/movesets.lua`
- Modify: `tests/unit/movesets_spec.lua`
- Modify: `tests/integration/phase_c_moves_ai_spec.lua`

**Interfaces:**
- Consumes: existing species/move/package inputs plus a new resource context.
- Produces: candidate pool containing only progression-legal machine moves and explicit techniques.

Add a final optional argument rather than rewriting every call at once:

```lua
resourceContext = {
  progression = snapshot,
  worldProgression = WorldProgression,
  tmProgression = TmProgression,
  trainer = {
    identity = "LT_SURGE",
    classId = "OPP_GENTLEMAN",
    kind = "standard" | "rival" | "boss" | "league",
  },
  exceptions = {
    THUNDERBOLT = { kind = "identity_exception", id = "LT_SURGE" },
  },
}
```

New signatures:

```lua
M.legal_pool(speciesDef, level, moveDefs, package, resourceContext)
M.generate(instance, speciesDef, moveDefs, movesetTier, package, teamContext, resourceContext)
M.refresh(instance, reason, speciesDef, moveDefs, movesetTier, package, teamContext, resourceContext)
```

- [ ] **Step 1: Add RED SolarBeam regression**

A level-5 Bulbasaur-compatible fixture at world stage 0 must exclude `SOLARBEAM` from `pool.tm`, regardless of score or tier.

- [ ] **Step 2: Add unlock regression**

The same species/context after the mapped SolarBeam source becomes available may include it, subject to compatibility and moveset tier.

- [ ] **Step 3: Add owner-exception regression**

A configured Gym owner exception may include its signature/reward technique before generic milestone unlock; an unrelated trainer may not.

- [ ] **Step 4: Implement machine filtering**

For every `speciesDef.tmhm` move:

```lua
local provenance = tmProgression.for_move(id, snapshot.version)
if not provenance then
  reject("unknown-machine-provenance")
elseif explicit_exception_allows(id, context) then
  append_with_provenance(...)
elseif worldProgression.resource_available(snapshot, provenance.availability, context) then
  append_with_provenance(...)
else
  reject(reason)
end
```

Do not silently fall back to old automatic legality when context is present.

For legacy/unit callers that intentionally pass no resource context, keep a narrowly documented compatibility behavior only until all production call sites migrate in Task 6. Add a test that every production path passes context before removing that compatibility branch.

- [ ] **Step 5: Persist structured provenance**

`instance.moveSources[id]` must distinguish at least:

```lua
{ kind = "level" }
{ kind = "tm", machine = "TM24", sourceId = "LT_SURGE_REWARD" }
{ kind = "technique", packageId = "...", exception = "identity" }
{ kind = "inherited" }
```

Update helper functions so source comparisons use `source.kind` rather than comparing the whole value to `"tm"`.

- [ ] **Step 6: Keep scoring downstream of legality**

Do not add progression penalties to `candidate_score`. Illegal moves must be absent, not merely scored lower.

- [ ] **Step 7: Run focused tests**

```bash
lua tests/unit/movesets_spec.lua
lua tests/integration/phase_c_moves_ai_spec.lua
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add src/core/movesets.lua tests/unit/movesets_spec.lua tests/integration/phase_c_moves_ai_spec.lua
git commit -m "feat: gate generated machine moves by world progression"
```

---

### Task 5: Separate tacticalTier from movesetTier

**Files:**
- Modify: `src/data/trainer_profiles.lua`
- Modify: `src/data/rival_windows.lua`
- Modify: `src/core/ai.lua`
- Modify: `src/core/standard_trainers.lua`
- Modify: `src/core/growth.lua`
- Modify: `src/core/bosses.lua`
- Modify: `src/core/league_run.lua`
- Modify: `main.lua`
- Modify: `tests/unit/ai_spec.lua`
- Modify: `tests/unit/movesets_spec.lua`
- Modify: `tests/integration/phase_c_moves_ai_spec.lua`
- Modify: `tests/integration/rival_version_paths_spec.lua`

**Interfaces:**
- Consumes: trainer profile/config.
- Produces: independent tactical and preparation sophistication values.

- [ ] **Step 1: Add RED separation tests**

Create a fixture with:

```lua
profile = { tacticalTier = 3, movesetTier = 0 }
```

Assert AI uses tier 3 switching/evaluation while moveset generation obeys tier 0 TM cap/scoring rules. Then invert the values and prove the concerns remain independent.

- [ ] **Step 2: Migrate profile data**

For each trainer profile, replace the old overloaded `aiTier` value with explicit fields while preserving current intended values initially:

```lua
tacticalTier = oldAiTier
movesetTier = oldAiTier
```

Do not rebalance ordinary trainer tiers in this task.

- [ ] **Step 3: Migrate Rival tuning**

Use:

```lua
tacticalTier = 3
movesetTier = 3
```

Oak's Lab remains bypassed by the companion plan. Route 22+ receives tactical tier 3.

- [ ] **Step 4: Migrate boss/League profiles**

Use explicit tactical tier 4 and moveset tier 4 unless a later balancing task deliberately changes a preparation tier.

- [ ] **Step 5: Update AI consumers**

`src/core/ai.lua` and battle context must read `tacticalTier` only.

- [ ] **Step 6: Update moveset consumers**

Every `movesets.generate`, `movesets.refresh` and diagnostic score call must receive `movesetTier`.

- [ ] **Step 7: Remove production dependence on overloaded `aiTier`**

A temporary test-fixture compatibility alias is acceptable only if existing tests require staged migration. Production code after this task must not use `profile.aiTier` for both concerns.

- [ ] **Step 8: Run focused suites**

```bash
lua tests/unit/ai_spec.lua
lua tests/unit/movesets_spec.lua
lua tests/integration/phase_c_moves_ai_spec.lua
lua tests/integration/rival_version_paths_spec.lua
```

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add src/data/trainer_profiles.lua src/data/rival_windows.lua src/core/ai.lua src/core/standard_trainers.lua src/core/growth.lua src/core/bosses.lua src/core/league_run.lua main.lua tests/unit/ai_spec.lua tests/unit/movesets_spec.lua tests/integration/phase_c_moves_ai_spec.lua tests/integration/rival_version_paths_spec.lua
git commit -m "refactor: separate trainer tactics from moveset tier"
```

---

### Task 6: Inject progression context into every generated moveset path

**Files:**
- Modify: `main.lua`
- Modify: `src/core/standard_trainers.lua`
- Modify: `src/core/growth.lua`
- Modify: `src/core/bosses.lua`
- Modify: `src/core/league_run.lua`
- Modify: Rival moveset assembly path (`src/core/rival.lua` and/or `main.lua`, based on current call ownership)
- Modify: `tests/integration/phase_b_persistence_spec.lua`
- Modify: `tests/integration/rival_version_paths_spec.lua`
- Modify: `tests/integration/gym_runtime_spec.lua`
- Modify: `tests/integration/league_persistence_spec.lua`

**Interfaces:**
- Consumes: `WorldProgression.snapshot(...)` and trainer identity.
- Produces: no production generated moveset without resource context.

- [ ] **Step 1: Construct one snapshot per safe runtime boundary**

In `main.lua`, derive the snapshot from the live public save/data plus `root.progression`. Do not let each Pokémon independently inspect the save.

Observe `map.entered` to add reached areas to persisted progression, then call `advance`.

- [ ] **Step 2: Pass standard-trainer context**

Recommended trainer identity payload:

```lua
trainer = {
  kind = "standard",
  classId = ctx.oppClass,
  identity = ctx.identityKey,
}
```

No identity exception unless explicitly configured in data.

- [ ] **Step 3: Pass Rival context**

Post-Oak Rival movesets receive `kind = "rival"`, encounter ID and no implicit all-TM exception.

- [ ] **Step 4: Pass boss/League context with explicit exceptions**

Translate configured signature/strategy techniques into explicit per-move exception records. Merely appearing in `package.techniques` is not enough to bypass machine progression unless the package data marks the move as an approved exception.

- [ ] **Step 5: Add a production-path guard test**

Instrument a test moveset service so every production generation/refresh call fails if `resourceContext.progression` is absent. Cover standard, Rival, Gym and League integration paths.

- [ ] **Step 6: Remove legacy no-context production behavior**

After all production paths are migrated, `movesets.legal_pool` may keep no-context behavior only for explicit isolated unit helpers such as `level_moves`; generated TM selection must require context.

- [ ] **Step 7: Run integration suites**

```bash
lua tests/integration/phase_b_persistence_spec.lua
lua tests/integration/rival_version_paths_spec.lua
lua tests/integration/gym_runtime_spec.lua
lua tests/integration/league_persistence_spec.lua
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add main.lua src/core/standard_trainers.lua src/core/growth.lua src/core/bosses.lua src/core/league_run.lua src/core/rival.lua tests/integration/phase_b_persistence_spec.lua tests/integration/rival_version_paths_spec.lua tests/integration/gym_runtime_spec.lua tests/integration/league_persistence_spec.lua
git commit -m "feat: apply world legality to trainer movesets"
```

Omit `src/core/rival.lua` if the current assembly path is entirely in `main.lua`.

---

### Task 7: Make boss techniques explicit and reviewable

**Files:**
- Modify: `src/data/boss_rosters.lua`
- Modify: `src/data/league_rosters.lua`
- Modify: `src/core/bosses.lua`
- Modify: `src/core/league_run.lua`
- Modify: `tests/unit/bosses_spec.lua`
- Modify: `tests/unit/league_run_spec.lua`
- Modify: `tests/integration/phase_d_bosses_spec.lua`

**Interfaces:**
- Consumes: world legality plus configured boss exceptions.
- Produces: every boss technique justified as world-legal or explicit exception.

- [ ] **Step 1: Add RED data-validation tests**

Every configured boss/League `signatureMoves`, `signatureExtras` and `techniques` entry must resolve to one of:

```text
world machine provenance
level/natural move
identity exception declared in the same boss data
Kanto+ exception declared in Kanto+ data/package
```

Fail with `leader/strategy/move` identifiers when justification is missing.

- [ ] **Step 2: Extend package data with explicit exception metadata**

Recommended shape:

```lua
exceptions = {
  THUNDERBOLT = { kind = "identity_exception", owner = "LT_SURGE" },
}
```

Do not mark every technique as an exception. Prefer normal world legality when appropriate.

- [ ] **Step 3: Preserve intended boss identity**

The purpose is to make exceptional resources explicit, not to strip challenge packages automatically. Review each early-boss technique deliberately.

Do not alter Brock's Aerodactyl/Rhyhorn species flex behavior in this task.

- [ ] **Step 4: Keep Kanto+ exceptions capability-gated**

A move/species exception that depends on Gold sidecar data must remain unavailable when Kanto+ is disabled.

- [ ] **Step 5: Run boss/League tests**

```bash
lua tests/unit/bosses_spec.lua
lua tests/unit/league_run_spec.lua
lua tests/integration/phase_d_bosses_spec.lua
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add src/data/boss_rosters.lua src/data/league_rosters.lua src/core/bosses.lua src/core/league_run.lua tests/unit/bosses_spec.lua tests/unit/league_run_spec.lua tests/integration/phase_d_bosses_spec.lua
git commit -m "feat: declare boss move resource exceptions"
```

---

### Task 8: Add progression-epoch moveset refresh

**Files:**
- Modify: `src/core/growth.lua`
- Modify: `src/core/standard_trainers.lua`
- Modify: Rival refresh path
- Modify: `tests/unit/growth_spec.lua`
- Modify: `tests/integration/phase_b_persistence_spec.lua`

**Interfaces:**
- Consumes: `progression.epoch` and instance/state `lastMovesetProgressionEpoch`.
- Produces: at most one safe `"progression"` refresh per epoch.

- [ ] **Step 1: Add RED idempotence tests**

Scenario:

```text
trainer generated at epoch 2
same epoch encounter -> no progression refresh
world advances to epoch 3 -> one progression refresh at next safe materialization
save/reload epoch 3 -> no second refresh
epoch 4 -> one new eligible refresh
```

- [ ] **Step 2: Extend refresh reason data**

Add a progression-specific margin to `src/data/move_packages.lua`, chosen conservatively and covered by before/after simulation. Do not silently reuse evolution's zero margin.

- [ ] **Step 3: Refresh only outside active battle mutation**

Use existing trainer materialization/encounter preparation boundaries. Never swap moves in the middle of a battle.

- [ ] **Step 4: Preserve existing legal moves**

Call normal `movesets.refresh(..., "progression", ...)`; do not regenerate all four moves on each epoch.

- [ ] **Step 5: Stamp epoch after the attempted refresh**

Stamp even when no better legal move exists, so repeated encounters at the same epoch do not repeatedly reconsider the same pool.

- [ ] **Step 6: Run focused persistence tests**

```bash
lua tests/unit/growth_spec.lua
lua tests/integration/phase_b_persistence_spec.lua
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add src/core/growth.lua src/core/standard_trainers.lua src/data/move_packages.lua tests/unit/growth_spec.lua tests/integration/phase_b_persistence_spec.lua
git commit -m "feat: refresh trainer moves on world progression"
```

Include the Rival file actually changed by the implementation.

---

### Task 9: Migrate v0.1.0 move provenance without resetting trainers

**Files:**
- Modify: `src/core/save_schema.lua`
- Modify: `src/core/movesets.lua`
- Modify: `tests/unit/save_schema_spec.lua`
- Modify: `tests/unit/movesets_spec.lua`
- Modify: `tests/integration/phase_b_persistence_spec.lua`
- Modify: `tests/integration/rival_version_paths_spec.lua`

**Interfaces:**
- Consumes: legacy string `moveSources`, current progression snapshot and species registry.
- Produces: structured provenance + deterministic correction of only demonstrably illegal generated resources.

- [ ] **Step 1: Add a RED legacy-save fixture**

Create v0.1-style trainer state with:

```lua
moveSources = {
  TACKLE = "level",
  SOLARBEAM = "tm",
}
```

at an early progression state where SolarBeam's machine source is unavailable.

Assert migration preserves identity/species/level/history and removes/replaces only the illegal generated machine move.

- [ ] **Step 2: Add a legal legacy TM fixture**

At a sufficiently advanced progression state, the same legacy generated TM should migrate to structured provenance without forced replacement.

- [ ] **Step 3: Preserve unknown inherited/vanilla moves conservatively**

A legacy move not proven generated by the mod must become `{ kind = "inherited" }` rather than being deleted solely because current progression cannot explain it.

- [ ] **Step 4: Implement idempotent schema migration**

Bump the schema/provenance version once. Repeated `schema.ensure` calls must produce byte-equivalent semantic state and no additional rerolls.

- [ ] **Step 5: Use deterministic legal replacement**

When a generated legacy TM is proven illegal, feed the instance through the same legal candidate ranking. Do not choose a random replacement outside the existing seeded generator.

- [ ] **Step 6: Run migration/persistence tests**

```bash
lua tests/unit/save_schema_spec.lua
lua tests/unit/movesets_spec.lua
lua tests/integration/phase_b_persistence_spec.lua
lua tests/integration/rival_version_paths_spec.lua
```

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add src/core/save_schema.lua src/core/movesets.lua tests/unit/save_schema_spec.lua tests/unit/movesets_spec.lua tests/integration/phase_b_persistence_spec.lua tests/integration/rival_version_paths_spec.lua
git commit -m "feat: migrate trainer move provenance"
```

---

### Task 10: Add sanitized progression diagnostics

**Files:**
- Modify: `src/core/diagnostics.lua`
- Modify: `src/ui/debug.lua`
- Modify: `src/core/movesets.lua`
- Modify: `tests/unit/diagnostics_spec.lua`
- Modify: `tests/integration/debug_runtime_spec.lua`

**Interfaces:**
- Consumes: progression snapshot and candidate rejection reports.
- Produces: developer-only explanation without private/raw data.

- [ ] **Step 1: Add RED diagnostic projection tests**

Require fields:

```text
progressionEpoch
worldStage
movesetTier
tacticalTier
moveProvenance
rejectedMoveCandidates
bossExceptionsApplied
```

- [ ] **Step 2: Add stable rejection reason codes**

At minimum:

```text
unknown-machine-provenance
world-stage-too-early
area-not-reached
milestone-incomplete
moveset-tier-cap
species-incompatible
identity-exception
kanto-plus-unavailable
```

- [ ] **Step 3: Keep diagnostics sanitized**

Do not expose ROM paths, cache prefixes, raw save blobs or player move/species lists as countering evidence.

- [ ] **Step 4: Run diagnostics tests**

```bash
lua tests/unit/diagnostics_spec.lua
lua tests/integration/debug_runtime_spec.lua
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add src/core/diagnostics.lua src/ui/debug.lua src/core/movesets.lua tests/unit/diagnostics_spec.lua tests/integration/debug_runtime_spec.lua
git commit -m "feat: explain trainer move progression"
```

---

### Task 11: Re-run deterministic balance simulations

**Files:**
- Modify: `docs/BALANCING.md`
- Modify property fixtures only when they model the old illegal resource policy.
- No production tuning change unless a failing balance property justifies it.

**Interfaces:**
- Consumes: completed resource/tier architecture.
- Produces: before/after distributions and explicit decision record.

- [ ] **Step 1: Run existing full property aggregate unchanged first**

The first run tells whether architecture alone shifts distributions.

- [ ] **Step 2: Add progression-specific simulations**

Sample early/mid/late snapshots across R/B/Y and assert:

```text
zero future machine resources in early stage
resource counts grow monotonically
T3 Rival remains tactically expert with bounded early moves
ordinary trainers do not converge on the same best late-game machines
boss identity packages remain valid
```

- [ ] **Step 3: Record before/after evidence**

Update `docs/BALANCING.md` with sample size, distributions, and any deliberate tuning change.

- [ ] **Step 4: Commit**

```bash
git add docs/BALANCING.md tests/property
git commit -m "test: validate progression-aware trainer balance"
```

Do not include unrelated property files that did not change.

---

### Task 12: Full release acceptance for progression integrity

**Files:**
- Modify: `tests/acceptance/definition_of_done.lua`
- Modify: `docs/DEFINITION_OF_DONE_AUDIT.md`
- Modify: `docs/IMPLEMENTATION_STATUS.md`
- Modify: `CHANGELOG.md` only when preparing the actual corrective release.

**Interfaces:**
- Consumes: Workstreams Oak + Gym + world progression.
- Produces: release-blocking evidence.

- [ ] **Step 1: Add aggregate acceptance cases**

Require:

```text
Oak exact vanilla parity
Route 22 Rival tactical T3 with progression-legal moves only
SolarBeam impossible in Oak/early world context
unique Gym reward unavailable generically before milestone
same reward legal after milestone
owner signature exception works
progression refresh once per epoch
v0.1 migration preserves trainer history
R/B/Y provenance completeness
Kanto-only fallback
Kanto+ exception remains capability-gated
```

- [ ] **Step 2: Run full ROM-free gate**

```bash
GEN1RECOMP_ROOT=/path/to/gen1recomp ./scripts/check.sh
GEN1RECOMP_ROOT=/path/to/gen1recomp SOURCE_DATE_EPOCH=0 ./scripts/package.sh
git diff --check
git status --short
```

Expected: PASS and byte-reproducible package.

- [ ] **Step 3: Run real Blue + Gold sidecar acceptance**

Using the same legal public DatasetViews path as the v0.1.0 acceptance:

```text
Oak vanilla battle
Route 22 adaptive Rival without impossible machine resource
standard trainer before/after representative world unlock
boss identity exception
Kanto+ weather/evolution path
save/reload + migration state
```

Capture only sanitized scenario results and exact engine/mod revisions.

- [ ] **Step 4: Update evidence ledgers**

Record exact commands, sample sizes and known deferred P1 reachability work.

- [ ] **Step 5: Commit**

```bash
git add tests/acceptance/definition_of_done.lua docs/DEFINITION_OF_DONE_AUDIT.md docs/IMPLEMENTATION_STATUS.md docs/BALANCING.md
git commit -m "docs: record progression integrity acceptance"
```

## Completion Gate

This workstream is complete only when every generated machine/technique resource can be explained by world progression or an explicit trainer/Kanto+ exception, tactical intelligence no longer grants resources, persistent saves migrate without reset, and the early Rival SolarBeam class of bug is impossible by construction.