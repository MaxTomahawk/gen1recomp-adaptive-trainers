# Implementation status

Updated: 2026-08-25

## Objective

Implement the complete approved Adaptive Trainer Ecology & Challenge System v1 as the standalone `adaptive_trainers` Gen1Recomp mod for Red, Blue, and Yellow. The authoritative product baseline and Definition of Done are in `Gen1Recomp_Adaptive_Trainers_Complete_Design_Spec_NL.docx`.

## Verified baseline

- Released engine baseline: `bryanthaboi/gen1recomp` `v0.2.25` at
  `08121faa3dd01ba68bb6bb74676650c5ebe1d116` (published and verified 2026-08-25). The release history
  contains the #1767 dataset-view merge `9dd38e06a578b0ed5e275934908fbd52e8a8c785`.
- Specification snapshot: `26e9e1d597060216168a03e49f138101726a8f3b`; upstream changes since that snapshot do not replace the trainer-party or Gym eligibility assumptions.
- Toolchain available: Git, authenticated GitHub CLI, LuaJIT, LÖVE, Python 3, upstream `tools/modkit.py`, and GitHub Actions.
- Intended mod id `adaptive_trainers` is valid under the current manifest rules.
- The official `v0.2.25` release contains every public seam required by the
  approved mod: trainer eligibility, charge decisions, active-independent
  imported dataset views, engine-owned field residual descriptors, and the
  public loader developer-mode signal. Final release claims still require a
  fresh Adaptive Trainers acceptance run against this exact release SHA.
- The public `trainer.before_battle` continuation and battle-local
  `playerPartyIndices` scope are available on current `dev`. The generic seam
  was merged through upstream PR `bryanthaboi/gen1recomp#1286` as merge commit
  `97a9c0f58fe8c0adca9ee8f5c57a84ebf3d84489`; the mod uses only that public
  contract and does not vendor or privately import engine code.

## Phase status

- [x] Phase A — identity, save schema, deterministic RNG, Kanto-only initial standard-trainer generation and persistence (PR #1 merged green at `928de80`)
- [x] Phase B — elapsed growth, local catches, Center-aware owned/active roster behavior (PRs #2/#3 merged green at `c84984e`)
- [x] Phase C — legal persistent movesets, AI sophistication tiers, property tests (PRs #4/#5 merged green at `3b44af8`)
- [x] Phase D — Gym registration and eligibility, eight Leader identities, challenge scaling (PR #6 merged green at `aa670b0`)
- [x] Phase E — Elite Four run snapshot and exactly-one-Bird mechanic
- [x] Phase F — persistent Rival journey, R/B/Y windows, Yellow Eevee outcomes
- [x] Phase G — optional Kanto+ sidecar, Steel, weather, minimal added moves
  (PR #13 merged green at `8866e2d`)
- [ ] Phase H — A-F diagnostics projections, acceptance aggregation, balancing
  evidence, and the exact-gated runtime dev surface are implemented locally;
  released-engine parity, release, and index submission remain open

## Current execution

Phases A-G are merged after green CI and clean independent reviews. Phase F
implements one persistent Rival collection that advances
through all eight canon encounters, uses deterministic variable route-window
budgets, trains/evolves every owned line through runtime metadata, persists T3
moves and attachment, and rotates teams without player species/move input.
Exact map/class/party-index tables cover every existing R/B/Y scripted path,
including battles without `world.trainer_engaged`; prepared, active, result and
checkpoint state remains isolated from ordinary, Gym and League authorities.
Yellow preserves exactly Vaporeon after an Oak loss, Jolteon after both early
wins, and Flareon after an Oak win plus Route 22 loss or skip.

The merged Phase E lifecycle preserves its run through internal Champion and
Hall-of-Fame transitions, clears it at the Hall-of-Fame autosave before the
title soft reset, and also clears on blackout, other League exits, or stale
post-game home loads so the next entry cannot inherit or reroll the prior run.

Phase G is implemented as a complete fail-closed sidecar. It admits the nine
approved Gold-derived continuations, Steel/type data, added moves, sprites, and
weather only after the full public dataset and battle capability set validates;
otherwise every existing individual remains or reconciles to a Kanto stage.
The combined-engine acceptance drives real dataset views, serialized battle
checkpoint restoration, SolarBeam charge bypass, engine-owned Sandstorm
residual/faint handling, immunities, and the Gold Steelix image/draw path.

Current evidence:

- Phase H A-F acceptance: 472/472 direct and aggregate checks passed against
  the audited upstream `dev` baseline, including an instrumented proof that
  filesystem spying is active before SDK discovery, detects public
  `mod.storage` and legacy-overlay writes, excludes engine-owned loader
  bookkeeping, and proves load/pre-generation perform neither mod persistence
  write while initialization changes only the mod's `mod.save` namespace. A
  64-seed boss-core loss variation simulation
  is also green; the genuine public loss lifecycle is
  covered separately by the Gym runtime suite. Diagnostic projection and exact
  `POKEPORT_DEV=1` adapter suites add 162/162 focused checks, including hostile
  value/cycle/metatable rejection, deep-detachment, every declared A-F choice
  label, and stable seed ordering. The public
  runtime boundary now adds 82/82 checks against the combined public-seam
  engine: exact boolean-only activation, all four command scopes, invalid and
  missing/surplus targets, detached stable screens, lossless wrapped drawing,
  scrolling/close, byte-identical read-only save/runtime/registry inputs,
  current ceiling/catch/ecology/move-score and boss admission evidence,
  production absence, exact seed-log text, and no reconstructed log on rerun
  or serialized reload. Generator-level and real runtime suites pin
  materialization ordering and seed parts for standard roster/catch/no-catch/
  growth/moves,
  boss strategy/flex/levels, League Bird/member strategy/party, and Rival
  starter/window/acquisition/party choices. The pending public API and API-v1
  no-mod parity suites are green at 23/23 and 12/12. This remains historical pre-release Phase H evidence; `v0.2.25` now contains
  the required public developer signal and final release evidence must be
  regenerated against that exact released-engine SHA.

- Public SDK loader: 7/7 checks passed.
- Phase A public runtime: 327/327 checks passed across Red, Blue, and Yellow,
  including 100 byte-equivalent reruns per version and serialized reloads.
- Phase B public runtime: 235/235 loss/growth/catch/rotation/reload checks,
  including collision-checkpoint reconstruction, concrete battle binding,
  skipped-loss handling, grace-safe legacy move hydration, full-party grace
  freezing, and Blue/Yellow badge-path coverage.
- Phase C public runtime: 35/35 persistent-move, evolution-refresh, merged-AI,
  tactical-switch, and serialized-reload checks.
- Phase D public runtime: 697/697 all-Leader Red/Blue/Yellow generation,
  registration, scoped-AI, persistence and result checks; public seam lifecycle
  47/47; standalone registration UI 33/33.
- Phase E public runtime: 147/147 Red/Blue/Yellow entry, member generation,
  Hall-of-Fame autosave/post-game recovery,
  save/reload, checkpoint, T4 AI, internal-transition and blackout/re-entry
  checks; League core 176/176.
- Phase F public runtime: 326/326 exact R/B/Y scripted-context, persistent
  journey, legal T3 move/AI, checkpoint, result-isolation and Yellow outcome
  checks; Rival core 182/182, including every exact canonical R/B starter and
  Yellow Eevee path row.
- Phase G public runtime: 74/74 checks; combined public-engine acceptance:
  26/26; Kanto-only fallback/root reconciliation: 163/163; Kanto+ unit/property
  coverage: 120/120; weather: 63/63.
- Deterministic/property suites: 372,974/372,974 assertions, including 61,357
  Rival fairness assertions proving level/time-equivalent builds are blind to
  complete player species and move-list changes, plus 86,250
  Gym identity/structure/repeatability assertions and 140,004 assertions over
  10,000 fully materialized four-member League runs. Each run fields exactly
  one allowed Bird; the deterministic sample is Articuno 4,984, Zapdos 2,562,
  and Moltres 2,454, within the normative 50/25/25 tolerances.
- `modkit validate --base fixture`: green.
- `modkit lint`: green, no ROM-derived content detected.
- The normal `scripts/package.sh` release workflow now makes the layout and
  reproducibility check mandatory: it validates the freshly created archive,
  builds exactly one temporary second archive through a non-recursive helper,
  compares SHA-256 hashes, and rejects repository-only paths before publishing
  the accepted archive. The first archive stays staged until that gate passes;
  a failed build removes any stale public artifact, and the gate does not
  consume a pre-existing `dist/` package.
- Phase H runtime double-pack: byte-identical and layout-clean at
  `SOURCE_DATE_EPOCH=0`; 38 distributable files plus `.modkit/pack.json`,
  including the detached diagnostics modules and developer-only choice logger,
  SHA-256
  `09a8e6cc94ff9a21f6a64cb7dfd81f9f68df54127dc595eeab95be5143bdee6d`.
  All required public seams are now present in official release `v0.2.25`;
  stable publication remains gated on fresh released-engine acceptance,
  private real-import acceptance, and the final Definition of Done audit.
- Last Phase-E reproducible double-pack check: green; 31 distributable files plus
  `.modkit/pack.json`, with no recursive `dist/`, tests, scripts, docs, or DOCX.
- Last merged Phase-E source-date-zero package SHA-256:
  `46fb2ec45aa0446a2d73f91e90cbafabdec086b6f790236439e043649eba9a52`.

The ROM-free fixture validator reports MK103 as not checkable for trainer-id
patch references; it remains green and cannot distinguish real vanilla ids from
typos without an imported data base. The current upstream trainer registry and
the mod's 1,990 data assertions independently cover every patched ordinary
class id without committing imported content.

## Baseline clarifications

- Appendix A omits Onix while the normative Kanto+ table requires Steelix.
  `ONIX_LINE` is therefore present with conservative Rock/Ground metadata; no
  gameplay decision was reopened.
- The Kanto+ prose says eight added evolutions but explicitly names nine.
  Metadata preserves all nine named continuations.
- Item/trade/friendship NPC evolution uses explicit surrogate thresholds in
  line metadata; ordinary level evolutions derive their exact threshold from
  the active runtime Pokémon registry.

The detailed implementation plan is `docs/superpowers/plans/2026-08-14-adaptive-trainers.md`.

## Engine seam ledger

### AT-SP-001 — battle-local player-party eligibility

- State: `MERGED_AVAILABLE` (`bryanthaboi/gen1recomp#1286`, merge commit
  `97a9c0f58fe8c0adca9ee8f5c57a84ebf3d84489`)
- Required by: Phase D Gym registration rule
- Missing capability: safely restrict every send, switch, auto-send, and exhaustion check to registered save-party indices without mutating `game.save.party`
- Existing APIs considered: `trainer.party`, `world.trainer_engaged`, registered screens, UI list widgets, battle lifecycle events, and checkpoint APIs
- Why insufficient: none controls the engine's player-party traversal or can atomically suspend a vanilla trainer engagement until a registration screen completes
- Implemented delta: generic additive `trainer.before_battle` deferred
  continuation plus ordered battle-local eligible indices, with cancellation,
  checkpoint preservation, item-target/menu/switch/auto-send/exhaustion/EXP
  enforcement, and no Adaptive Trainers policy
- Verification: 167/167 engine suites and 19/19 modkit suites green locally;
  dedicated party-scope 20/20, public-hook 15/15, and trainer cancel lifecycle
  24/24; independent review reports no findings
- Release gate: cleared in official Gen1Recomp release `v0.2.25`; stable
  publication still waits for the complete mod Definition of Done

### AT-SP-002 — charge-stage decision

- State: `MERGED_AVAILABLE` (`bryanthaboi/gen1recomp#1645`, merge commit
  `a1a70540b84f58c16c1b7410a23b517a2b65dd1a`)
- Required by: Phase G Sunny Day making SolarBeam skip its charge turn without
  replacing the engine move pipeline
- Missing capability: a public ruleset decision at an existing move's initial
  charge boundary
- Existing APIs considered: move effects, `battle.damage`, registered moves,
  and battle lifecycle events; none runs before private charge state is created
- Implemented delta: generic guarded shared `battle.charge_required` hook for
  Gen 1 and Gen 2, with engine-owned PP, accuracy, animation, damage, and effect
  semantics preserved
- Verification: focused public/no-mod coverage, Gen 1/Gen 2 compatibility gates,
  full engine/modkit suites, independent clean review, and upstream CI green
- Release gate: cleared in official Gen1Recomp release `v0.2.25`

### AT-SP-003 — active-independent semantic dataset view

- State: `RELEASED_AVAILABLE` (`bryanthaboi/gen1recomp#1767`, merge commit
  `9dd38e06a578b0ed5e275934908fbd52e8a8c785`, released in `v0.2.25` at `08121faa3dd01ba68bb6bb74676650c5ebe1d116`)
- Required by: Phase G optional Kanto+ content derived from the player's valid
  Gold import while Red, Blue, or Yellow remains active
- Public delta: bounded read-only `mod.datasets` semantic views and sanitized
  selected-cache generated asset paths without raw ROM bytes, generated Lua
  execution, mount changes, or active-game authority changes
- Verification at merge: full upstream ROM-free CI and focused cache/dataset
  regressions were green on the integrated PR head; the official release is an
  ancestor-preserving descendant of that merge
- Release gate: engine seam cleared; final mod acceptance against the exact
  released engine remains required

### AT-SP-004 — engine-owned field residual application

- State: `RELEASED_AVAILABLE` (`bryanthaboi/gen1recomp#1766`, merge commit
  `0ab4ef2755c84df38b22566570950b1a7ce36e81`, released by `v0.2.25`)
- Required by: Phase G Gen 2-style Sandstorm residual damage after vanilla
  status residuals and before weather expiry
- Public delta: guarded data-only `battle.field_residual` descriptors while the
  engine retains HP, faint, result, EXP, replacement, and checkpoint authority
- Release gate: engine seam cleared; final mod acceptance against the exact
  released engine remains required

### Trainer identity context

No engine change is currently justified. `world.trainer_engaged` exposes the concrete NPC id and trainer tuple before ordinary overworld battles; `mod.world:current()` supplies the map. Scripted canon battles can use explicit map/class/party identities.

Battle-checkpoint reconstruction restores `mod.save` before invoking the public
`trainer.party` hook. The mod therefore persists the active concrete identity
in its checkpointed save state and reuses it during reconstruction; this closes
the collision case without private imports or a new engine seam.

### AT-SP-005 — dev-only diagnostics activation

- State: `RELEASED_AVAILABLE` (`bryanthaboi/gen1recomp#1769`, merge commit
  `ff826ce01e47e523e0e265c5856cb4d7cb6d1a89`, released by `v0.2.25`)
- Required by: Phase H runtime access to Chapter 30 diagnostic projections only
  for developer boots
- Public delta: fixed boolean `mod.developer`, available before the sandboxed
  mod entry chunk runs and granting no additional permission
- Current safe boundary: diagnostics register only when
  `mod.developer == true`; false, nil, and non-boolean values remain inert and
  no environment shim, export, `mod.storage`, or private import is used
- Release gate: engine seam cleared; final released-engine diagnostics and
  no-mod parity acceptance remain required
