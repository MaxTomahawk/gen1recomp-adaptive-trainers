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

- [ ] Phase A — identity, save schema, deterministic RNG, Kanto-only initial standard-trainer generation and persistence (all local gates green; PR #1 re-review pending)
- [ ] Phase B — elapsed growth, local catches, Center-aware owned/active roster behavior
- [ ] Phase C — legal persistent movesets, AI sophistication tiers, property tests
- [ ] Phase D — Gym registration and eligibility, eight Leader identities, challenge scaling
- [ ] Phase E — Elite Four run snapshot and exactly-one-Bird mechanic
- [ ] Phase F — persistent Rival journey, R/B/Y windows, Yellow Eevee outcomes
- [ ] Phase G — optional Kanto+ sidecar, Steel, weather, minimal added moves
- [ ] Phase H — diagnostics, balancing simulations, integration, parity, packaging, release and index submission

## Current execution

Phase A implementation is complete locally on `agent/phase-a` and published in
PR #1. An independent review found missing runtime encounter-bucket weighting,
placeholder role/team scoring, incomplete rarity/type repair invariants, unused
indoor ecology overrides, and a non-cooperative trainer hook. The branch now
contains tested remediations. A first re-review then caught the live Psychic
class-id mismatch and an incomplete exhausted-repair fallback; both now have
focused regression coverage. Fresh CI and final independent re-review are the
active gates. Phase B begins as soon as the Phase A branch is integrated green.

Current evidence:

- Public SDK loader: 6/6 checks passed.
- Phase A public runtime: 327/327 checks passed across Red, Blue, and Yellow,
  including 100 byte-equivalent reruns per version and serialized reloads.
- Deterministic/property/unit suites: 17,000/17,000 property assertions plus
  4,517 focused data/ecology/generation/identity/power/RNG/schema assertions.
- `modkit validate --base fixture`: green.
- `modkit lint`: green, no ROM-derived content detected.
- Reproducible double-pack check: green; 19 distributable files plus
  `.modkit/pack.json`, with no recursive `dist/`, tests, scripts, docs, or DOCX.
- Source-date-zero package SHA-256:
  `28c2c4644c2a5f947b2d033546f80410ecd549eb6c4bc92865d2804d018b1316`.

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
