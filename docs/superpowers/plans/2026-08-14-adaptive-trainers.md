# Adaptive Trainers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete approved Adaptive Trainer Ecology & Challenge System v1 as a production-quality standalone Gen1Recomp mod for Red, Blue, and Yellow.

**Architecture:** The distributable repository root is the mod root. Pure Lua modules under `src/` own deterministic generation and state transitions; `main.lua` is a thin public-API adapter. Authoritative gameplay state lives only in `mod.save`, runtime game data is read from merged public registries or the `game.ready` payload, and optional Kanto+ content is a capability-detected overlay.

**Tech Stack:** Lua 5.1/LuaJIT, Gen1Recomp mod API 2, upstream `tools/modkit.py`, LuaJIT tests, shell check/package scripts, GitHub Actions.

## Global Constraints

- The DOCX design baseline is normative; MUST/SHOULD/MAY and its Definition of Done retain their stated force.
- Mod id is `adaptive_trainers`; supported games are exactly `red`, `blue`, and `yellow`.
- Use only public mod APIs in the distributed package; never require `src.*` engine modules.
- Store trainer, boss, Rival, League, and seed authority only in `mod.save`; never duplicate it in `mod.storage`.
- Never use global `math.random` for persistent gameplay choices.
- Never distribute ROM-derived bytes or extracted cartridge registries.
- Preserve vanilla behavior when the mod is disabled and preserve version-correct R/B/Y inputs when enabled.
- Existing generated individuals survive migrations; missing Kanto+ content degrades without rerolling line identity.
- Engine changes require the repository's RFC, compatibility, public-API, and no-mod parity gates and must remain generic.

---

### Task 1: Repository and compatibility baseline

**Files:**
- Create: `manifest.json`, `mod.card`, `CHANGELOG.md`, `.luarc.json`
- Create: `scripts/check.sh`, `scripts/package.sh`, `.github/workflows/ci.yml`
- Modify: `README.md`, `docs/IMPLEMENTATION_STATUS.md`

**Interfaces:**
- Produces: stable `./scripts/check.sh` and `./scripts/package.sh` entrypoints parameterized by `GEN1RECOMP_ROOT`
- Consumes: upstream `tools/modkit.py`, LuaJIT, and the repository root as the standalone mod directory

- [x] Write a headless loader test that fails because `main.lua` and the manifest contract do not yet exist.
- [x] Add the manifest/card/changelog and a minimal public-API entrypoint, then verify the loader test passes.
- [x] Add check and package scripts that run unit tests, modkit validate, lint, and reproducible pack against an explicit engine root.
- [x] Add GitHub Actions using the audited `bryanthaboi/gen1recomp@dev` SHA and run the same entrypoints.
- [x] Commit as `chore: establish standalone mod toolchain`.

### Task 2: Phase A — deterministic identity, save, RNG, and initial rosters

**Files:**
- Create: `src/core/rng.lua`, `src/core/save_schema.lua`, `src/core/identity.lua`, `src/core/player_power.lua`
- Create: `src/core/ecology.lua`, `src/core/species_selector.lua`, `src/core/team_validator.lua`, `src/core/stage_resolver.lua`, `src/core/standard_trainers.lua`
- Create: `src/data/line_meta.lua`, `src/data/replacement_groups.lua`, `src/data/trainer_profiles.lua`, `src/data/ecology_overrides.lua`
- Create: `tests/unit/rng_spec.lua`, `tests/unit/save_schema_spec.lua`, `tests/unit/identity_spec.lua`, `tests/unit/standard_trainers_spec.lua`, `tests/integration/phase_a_mod_spec.lua`
- Modify: `main.lua`, `.modkitignore`, `docs/IMPLEMENTATION_STATUS.md`

**Interfaces:**
- `rng.seed(parts: table) -> {hi: uint32, lo: uint32}`
- `rng.stream(rootSeed, label, ...):next_u32()/float()/integer(min,max)/choice(rows)`
- `save_schema.ensure(root, saveIdentity) -> root`
- `identity.standard(version, mapId, oppClass, partyIndex, npcId?) -> string`
- `player_power.reference(party) -> number`
- `ecology.resolve(data, mapId, profile) -> candidate evidence rows`
- `standard_trainers.build(ctx, vanillaParty, root, services) -> partyDef, TrainerState`

- [x] Write RNG vector, stream-separation, and 100-rerun repeatability tests; run them and observe the missing-module failure.
- [x] Implement the two-word deterministic hash/PRNG without `math.random`; rerun to green.
- [x] Write schema initialization, idempotence, migration preservation, and Kanto+ suspended-stage tests; run red, implement, run green.
- [x] Write identity tests for version/map/class/party and NPC collision suffixes; run red, implement, run green.
- [x] Write player-reference and initial-catch-up boundary tests; run red, implement, run green.
- [x] Write ecology BFS, class affinity, version-input, legendary exclusion, duplicate-line, stage, and ±12% power tests; run red.
- [x] Implement full Kanto line metadata and data-driven class profiles from the baseline, selector scoring, bounded conflict rerolls, stage resolution, and validator; run green.
- [x] Write persistence and byte-equivalent party tests through the public `trainer.party` hook; run red.
- [x] Implement the thin runtime adapter using `game.ready`, `world.trainer_engaged`, `mod.world:current()`, registry iteration, and `mod.save`; run green.
- [x] Run all unit/integration tests, modkit validate, and modkit lint; update status evidence and commit as `feat: add persistent standard trainer generation`.

### Task 3: Phase B — elapsed growth, catches, and roster rotation

**Files:**
- Create: `src/core/growth.lua`, `src/core/roster.lua`
- Extend: `src/core/ecology.lua`, `src/core/standard_trainers.lua`, `src/data/trainer_profiles.lua`
- Test: `tests/unit/growth_spec.lua`, `tests/unit/catch_spec.lua`, `tests/unit/roster_spec.lua`, `tests/integration/phase_b_persistence_spec.lua`

**Interfaces:**
- `growth.materialize(state, ctx, profile, stream) -> changed`
- `roster.maybe_catch(state, ctx, profile, candidates, stream) -> PokemonInstance?`
- `roster.rotate(state, profile, centerDistance) -> activeIds`

- [x] Test the 900-second exact-grace boundary, saturating monotonic growth, contextual/lifetime ceilings, deterministic rounding, and permanent evolution before implementation.
- [x] Implement growth and rerun the focused suite to green.
- [x] Test at-most-one catch, ecology/context membership, legendary ban, catch-level bounds, and class-rate differences before implementation.
- [x] Implement catch materialization and rerun to green.
- [x] Test full-party behavior with and without reachable Centers plus collector/expert rotation differences before implementation.
- [x] Implement Center graph indexing and active/bench rotation, rerun all tests, validate/lint, update status, and commit as `feat: add trainer growth and catches`.
- [x] Address independent review with regressions for exact evidenced catch species, party-index-bounded issued pools, checkpoint-safe collision identity, directed warps, complete full-party catch behavior, and Red/Blue/Yellow persistence.
- [x] Keep the exact chapter 7.2 contextual ceiling separate from the no-level-down guard, including an already-above-cap regression.

### Task 4: Phase C — persistent legal movesets and AI tiers

**Files:**
- Create: `src/core/movesets.lua`, `src/core/ai.lua`, `src/data/move_packages.lua`
- Test: `tests/unit/movesets_spec.lua`, `tests/unit/ai_spec.lua`, `tests/property/standard_trainer_properties.lua`
- Modify: `main.lua`, `src/core/standard_trainers.lua`

**Interfaces:**
- `movesets.generate(instance, speciesDef, moveDefs, tier, package?, stream) -> moveIds`
- `movesets.refresh(instance, reason, ...) -> persisted moveIds`
- `ai.register(mod) -> nil`

- [ ] Test level/TM legality, tier limits, STAB availability, redundancy, four-slot limits, refresh memory, and persisted reruns before implementation.
- [ ] Implement role scoring and refresh semantics; run green.
- [ ] Test tactical tier behavior independently from roster construction and prove Rival/team builders receive no player-species data.
- [ ] Register class-driven AI records through `mod.content.ai_classes`, run property tests and all prior suites, validate/lint, update status, and commit as `feat: add trainer movesets and ai tiers`.

### Task 5: Phase D — Gym challenge framework

**Files:**
- Create: `src/core/bosses.lua`, `src/data/boss_rosters.lua`, `src/data/battle_identities.lua`, `src/ui/gym_registration.lua`
- Test: `tests/unit/bosses_spec.lua`, `tests/property/gym_properties.lua`, `tests/integration/gym_registration_spec.lua`
- Engine only if AT-SP-001 remains necessary: separate checkout RFC, generic API implementation, docs, public-API test, no-mod parity test

**Interfaces:**
- `bosses.build(identity, ctx, root, services) -> partyDef`
- `gym_registration.choose(game, leaderId, maxCount, onConfirm, onCancel) -> screen`
- Candidate generic engine contract: pre-battle continuation plus battle-local eligible player indices

- [ ] Re-audit upstream at the current `dev` SHA and attempt a public-API-only registration/mask test.
- [ ] If the test proves the gap, prepare the minimal generic RFC and fork branch from that upstream SHA; keep mod work independent until the seam merges/releases.
- [ ] Test exact R/B/Y N values, top-N reference repetition, signature `R1+1`, other matched levels, vanilla floors, structural packages, stable reloads, and post-loss attempt increments before boss implementation.
- [ ] Implement all eight baseline identities, pools, signatures, and strategies as data; run green.
- [ ] Test mask enforcement across initial send, menu, switch, auto-send, exhaustion, checkpoint restore, and cancel; implement only through the admitted public seam.
- [ ] Run mod and engine parity suites, validate/lint, update status and commits/PR evidence.

### Task 6: Phase E — Elite Four run snapshot and Legendary Bird

**Files:**
- Create: `src/core/league_run.lua`, extend `src/data/boss_rosters.lua`
- Test: `tests/unit/league_run_spec.lua`, `tests/property/league_bird_simulation.lua`, `tests/integration/league_persistence_spec.lua`

**Interfaces:**
- `league_run.enter(root, ctx, services) -> LeagueRun`
- `league_run.party(root, memberId, services) -> partyDef`
- `league_run.leave(root, reason) -> nil`

- [ ] Test one-time top-five snapshots, member party persistence, blackout/new-entry counter behavior, signature preservation, and reload stability before implementation.
- [ ] Test 10,000 generated runs for exactly one visible Bird, only Lorelei/Articuno or Lance/Zapdos/Moltres, and 50/25/25 statistical tolerance.
- [ ] Implement the four identities and run lifecycle; run all tests, validate/lint, update status, and commit as `feat: add adaptive elite four runs`.

### Task 7: Phase F — persistent Rival journey

**Files:**
- Create: `src/core/rival.lua`, `src/data/rival_windows.lua`
- Test: `tests/unit/rival_spec.lua`, `tests/property/rival_fairness.lua`, `tests/integration/rival_version_paths_spec.lua`

**Interfaces:**
- `rival.build(encounterId, ctx, root, services) -> partyDef`
- `rival.record_result(encounterId, result, root) -> RivalState`

- [ ] Test window budgets/areas, persistent acquisition origins, starter attachment 100, use/attachment increments, core bonus, bounded level pressure, canonical floors, and team rotation before implementation.
- [ ] Implement R/B and Yellow encounter anchors and windows; run green.
- [ ] Prove changing the complete player species/move list cannot change the Rival party when levels/time/owned state match.
- [ ] Test and implement Yellow outcomes exactly: Oak loss to Vaporeon; both wins to Jolteon; Oak win plus Route 22 loss/skip to Flareon.
- [ ] Run all suites, validate/lint, update status, and commit as `feat: add persistent rival journey`.

### Task 8: Phase G — optional Kanto+ sidecar and weather

**Files:**
- Create: `src/data/kanto_plus.lua`, `src/core/weather.lua`
- Test: `tests/unit/kanto_plus_spec.lua`, `tests/unit/weather_spec.lua`, `tests/integration/kanto_fallback_spec.lua`

**Interfaces:**
- `kanto_plus.detect(registries) -> capabilities`
- `kanto_plus.apply(mod, capabilities) -> nil`
- `weather.install(mod) -> nil`

- [ ] Test core operation with every post-Gen1 id absent and reversible suspended-stage fallback before implementation.
- [ ] Test capability detection and runtime-registry derivation for the specified eight evolutions, Steel chart/category, three Steel moves, three weather moves, Sludge Bomb, and Shadow Ball.
- [ ] Implement the optional sidecar without extracted data; run green.
- [ ] Test five-turn rain/sun/sand effects, exclusions, SolarBeam behavior, and no-weather parity; implement via public hooks/registries.
- [ ] Run all suites, validate/lint, update status, and commit as `feat: add optional kanto plus sidecar`.

### Task 9: Phase H — diagnostics, full audit, delivery

**Files:**
- Create: `src/core/diagnostics.lua`, `src/ui/debug.lua`, `tests/acceptance/definition_of_done.lua`, `docs/DEFINITION_OF_DONE_AUDIT.md`, `docs/BALANCING.md`
- Modify: `README.md`, `CHANGELOG.md`, `mod.card`, `docs/IMPLEMENTATION_STATUS.md`, CI and packaging scripts

**Interfaces:**
- `diagnostics.standard/boss/rival/league(...) -> data-only report`
- Dev screen and seed logs activate only under `POKEPORT_DEV`

- [ ] Write acceptance checks for every Definition of Done bullet and map each to authoritative automated or manual evidence.
- [ ] Implement trainer, boss, Rival, and League diagnostics plus dev-only seed-label logging.
- [ ] Run balancing simulations and record justified data changes without weakening hard invariants.
- [ ] Run all targeted tests, upstream relevant regression suites, modkit validate/lint, reproducible double-pack comparison, archive manifest inspection, R/B/Y coverage, disabled no-mod parity, and ROM-content scan.
- [ ] Drive mod PR CI/review to green and merge; resolve any upstream engine review/CI independently while keeping release dependency gated.
- [ ] Only after the audit proves every item, publish the initial stable release and follow the then-current mod-index submission process.
