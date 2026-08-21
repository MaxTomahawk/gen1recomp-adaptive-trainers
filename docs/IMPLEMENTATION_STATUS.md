# Implementation status

Updated: 2026-08-21

## Objective

Implement the complete approved Adaptive Trainer Ecology & Challenge System v1 as the standalone `adaptive_trainers` Gen1Recomp mod for Red, Blue, and Yellow. The authoritative product baseline and Definition of Done are in `Gen1Recomp_Adaptive_Trainers_Complete_Design_Spec_NL.docx`.

## Verified baseline

- Upstream: `bryanthaboi/gen1recomp` `dev` at `c11c762f15ce3f62335f60049ef35db379b75772` (2026-08-21).
- Specification snapshot: `26e9e1d597060216168a03e49f138101726a8f3b`; upstream changes since that snapshot do not replace the trainer-party or Gym eligibility assumptions.
- Toolchain available: Git, authenticated GitHub CLI, LuaJIT, LÖVE, Python 3, upstream `tools/modkit.py`, and GitHub Actions.
- Intended mod id `adaptive_trainers` is valid under the current manifest rules.
- Current public seams cover trainer party replacement, registry reads, per-save mod state, migrations, world context, trainer-engagement context, screens, battle lifecycle events, and weather hooks.
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
- [ ] Phase G — optional Kanto+ sidecar, Steel, weather, minimal added moves
- [ ] Phase H — diagnostics, balancing simulations, integration, parity, packaging, release and index submission

## Current execution

Phases A-E are merged after green CI and clean independent reviews. Phase F is
implemented on its feature branch: one persistent Rival collection advances
through all eight canon encounters, uses deterministic variable route-window
budgets, trains/evolves every owned line through runtime metadata, persists T3
moves and attachment, and rotates teams without player species/move input.
Exact map/class/party-index tables cover every existing R/B/Y scripted path,
including battles without `world.trainer_engaged`; prepared, active, result and
checkpoint state remains isolated from ordinary, Gym and League authorities.
Yellow preserves exactly Vaporeon after an Oak loss, Jolteon after both early
wins, and Flareon after an Oak win plus Route 22 loss or skip.

Current evidence:

- Public SDK loader: 7/7 checks passed.
- Phase A public runtime: 327/327 checks passed across Red, Blue, and Yellow,
  including 100 byte-equivalent reruns per version and serialized reloads.
- Phase B public runtime: 235/235 loss/growth/catch/rotation/reload checks,
  including collision-checkpoint reconstruction, concrete battle binding,
  skipped-loss handling, grace-safe legacy move hydration, full-party grace
  freezing, and Blue/Yellow badge-path coverage.
- Phase C public runtime: 35/35 persistent-move, evolution-refresh, merged-AI,
  tactical-switch, and serialized-reload checks.
- Phase D public runtime: 679/679 all-Leader Red/Blue/Yellow generation,
  registration, scoped-AI, persistence and result checks; public seam lifecycle
  38/38; standalone registration UI 33/33.
- Phase E public runtime: 123/123 Red/Blue/Yellow entry, member generation,
  save/reload, checkpoint, T4 AI, internal-transition and blackout/re-entry
  checks; League core 127/127.
- Phase F public runtime: 295/295 exact R/B/Y scripted-context, persistent
  journey, legal T3 move/AI, checkpoint, result-isolation and Yellow outcome
  checks; Rival core 160/160, including every exact canonical R/B starter and
  Yellow Eevee path row.
- Deterministic/property suites: 367,574/367,574 assertions, including 55,957
  Rival fairness assertions proving level/time-equivalent builds are blind to
  complete player species and move-list changes, plus 86,250
  Gym identity/structure/repeatability assertions and 140,004 assertions over
  10,000 fully materialized four-member League runs. Each run fields exactly
  one allowed Bird; the deterministic sample is Articuno 4,984, Zapdos 2,562,
  and Moltres 2,454, within the normative 50/25/25 tolerances.
- `modkit validate --base fixture`: green.
- `modkit lint`: green, no ROM-derived content detected.
- Last Phase-E reproducible double-pack check: green; 31 distributable files plus
  `.modkit/pack.json`, with no recursive `dist/`, tests, scripts, docs, or DOCX.
- Last Phase-E source-date-zero package SHA-256:
  `6bf502943463efa8a7decb7b305a6fdd308d9ab3bf84b84e7038d397b977bf78`.

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
- Release gate: cleared on current upstream `dev`; stable publication still
  waits for the complete mod Definition of Done, not for another engine change

### Trainer identity context

No engine change is currently justified. `world.trainer_engaged` exposes the concrete NPC id and trainer tuple before ordinary overworld battles; `mod.world:current()` supplies the map. Scripted canon battles can use explicit map/class/party identities.

Battle-checkpoint reconstruction restores `mod.save` before invoking the public
`trainer.party` hook. The mod therefore persists the active concrete identity
in its checkpointed save state and reuses it during reconstruction; this closes
the collision case without private imports or a new engine seam.
