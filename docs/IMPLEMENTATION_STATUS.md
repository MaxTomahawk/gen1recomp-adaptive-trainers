# Implementation status

Updated: 2026-08-14

## Objective

Implement the complete approved Adaptive Trainer Ecology & Challenge System v1 as the standalone `adaptive_trainers` Gen1Recomp mod for Red, Blue, and Yellow. The authoritative product baseline and Definition of Done are in `Gen1Recomp_Adaptive_Trainers_Complete_Design_Spec_NL.docx`.

## Verified baseline

- Upstream: `bryanthaboi/gen1recomp` `dev` at `f4658b89aedd5b222541074d3dfdbca9136c0b23` (2026-08-14).
- Specification snapshot: `26e9e1d597060216168a03e49f138101726a8f3b`; upstream changes since that snapshot do not replace the trainer-party or Gym eligibility assumptions.
- Toolchain available: Git, authenticated GitHub CLI, LuaJIT, LÖVE, Python 3, upstream `tools/modkit.py`, and GitHub Actions.
- Intended mod id `adaptive_trainers` is valid under the current manifest rules.
- Current public seams cover trainer party replacement, registry reads, per-save mod state, migrations, world context, trainer-engagement context, screens, battle lifecycle events, and weather hooks.
- No public battle-local player-party eligibility mask exists. A later Phase D engine prerequisite may be required; no engine code has been changed.

## Phase status

- [x] Phase A — identity, save schema, deterministic RNG, Kanto-only initial standard-trainer generation and persistence (PR #1 merged green at `928de80`)
- [x] Phase B — elapsed growth, local catches, Center-aware owned/active roster behavior (PRs #2/#3 merged green at `c84984e`)
- [ ] Phase C — legal persistent movesets, AI sophistication tiers, property tests (local gates green; review/PR pending)
- [ ] Phase D — Gym registration and eligibility, eight Leader identities, challenge scaling
- [ ] Phase E — Elite Four run snapshot and exactly-one-Bird mechanic
- [ ] Phase F — persistent Rival journey, R/B/Y windows, Yellow Eevee outcomes
- [ ] Phase G — optional Kanto+ sidecar, Steel, weather, minimal added moves
- [ ] Phase H — diagnostics, balancing simulations, integration, parity, packaging, release and index submission

## Current execution

Phases A and B merged after green CI and clean independent reviews. Phase C is
implemented locally on `agent/phase-c`: runtime-registry move legality,
persistent move/source memory, conservative level/evolution refreshes, and
class-driven T0-T3 AI are green through pure tests and the live public AI
registries. The next gates are independent Phase C review, repository PR CI,
and merge; Phase D then begins immediately.

Current evidence:

- Public SDK loader: 6/6 checks passed.
- Phase A public runtime: 327/327 checks passed across Red, Blue, and Yellow,
  including 100 byte-equivalent reruns per version and serialized reloads.
- Phase B public runtime: 235/235 loss/growth/catch/rotation/reload checks,
  including collision-checkpoint reconstruction, concrete battle binding,
  skipped-loss handling, grace-safe legacy move hydration, full-party grace
  freezing, and Blue/Yellow badge-path coverage.
- Phase C public runtime: 16/16 persistent-move, evolution-refresh, merged-AI,
  tactical-switch, and serialized-reload checks.
- Deterministic/property/unit suites: 71,363/71,363 property assertions plus
  4,655 focused AI/data/ecology/generation/growth/catch/moveset/roster/
  identity/power/RNG/schema assertions.
- `modkit validate --base fixture`: green.
- `modkit lint`: green, no ROM-derived content detected.
- Reproducible double-pack check: green; 24 distributable files plus
  `.modkit/pack.json`, with no recursive `dist/`, tests, scripts, docs, or DOCX.
- Source-date-zero package SHA-256:
  `095e71dd93fa811eb297f1aa5d6cae3b8a1300d4cd8aec9a3bf87c51cd6284c9`.

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

- State: `CANDIDATE`
- Required by: Phase D Gym registration rule
- Missing capability: safely restrict every send, switch, auto-send, and exhaustion check to registered save-party indices without mutating `game.save.party`
- Existing APIs considered: `trainer.party`, `world.trainer_engaged`, registered screens, UI list widgets, battle lifecycle events, and checkpoint APIs
- Why insufficient: none controls the engine's player-party traversal or can atomically suspend a vanilla trainer engagement until a registration screen completes
- Candidate delta: a generic additive pre-trainer-battle gate plus a battle-local eligible-index mask, with no Adaptive Trainers policy
- Gate before implementation: re-audit current upstream, write the required RFC, prove no-mod parity and public-API behavior, then develop from current upstream `dev` on a fresh fork branch

### Trainer identity context

No engine change is currently justified. `world.trainer_engaged` exposes the concrete NPC id and trainer tuple before ordinary overworld battles; `mod.world:current()` supplies the map. Scripted canon battles can use explicit map/class/party identities.

Battle-checkpoint reconstruction restores `mod.save` before invoking the public
`trainer.party` hook. The mod therefore persists the active concrete identity
in its checkpointed save state and reuses it during reconstruction; this closes
the collision case without private imports or a new engine seam.
