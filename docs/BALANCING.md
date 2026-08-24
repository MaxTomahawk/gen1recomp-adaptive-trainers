# Balancing evidence

Updated: 2026-08-24

The normative design document remains the authority. This file records the
deterministic simulations used to challenge its constants; it does not create
a second balance specification. No balance constant changed in this Phase H
A-F package because the recorded distributions and invariant checks remain
inside their approved bands.

## Current simulations

| System | Deterministic sample | Result | Decision |
|---|---:|---|---|
| Initial standard trainers | 17,000 Phase A property assertions | Repeatable across Red/Blue/Yellow; first-team power remains in the approved band | Retain current profile table |
| Standard growth/catches | 6,363 Phase B property assertions | Grace boundary, monotonic capped growth, at-most-one catch, ecology exclusions, and collector/expert frequency separation hold | Retain current growth and catch curves |
| Moves and AI | Included in the 372,974 merged A-F property total | Legal persistent moves and tier behavior remain deterministic | Retain data-driven packages and tier weights |
| Gym identities | 86,250 assertions | Eight Leaders across R/B/Y retain N, signature, floors, level formula, structural identity, repeatability, and player-species blindness | Retain current pools/packages/floors |
| Gym core loss variation | 64 fixed seed pairs in `tests/acceptance/definition_of_done.lua` | Every regenerated attempt is valid; 22 pairs change strategy or flex roster; the public loss lifecycle remains covered by `tests/integration/gym_runtime_spec.lua` | Retain attempt-counter seed input |
| League Birds | 10,000 complete four-member runs; 140,004 assertions | Articuno 4,984, Zapdos 2,562, Moltres 2,454; exactly one allowed visible Bird per run | Retain 50/25/25 selection weights |
| Rival fairness | 61,357 assertions | Level/time-equivalent inputs remain unchanged when the complete player species and move lists change; pressure stays bounded | Retain Rival pressure and attachment tuning |

The executable aggregate is `tests/acceptance/definition_of_done.lua`. Focused
property suites remain the source of detailed counterexamples and are rerun in
isolated Lua processes by that aggregate.

## Balance authority

- Standard trainer values live centrally in
  `src/data/trainer_profiles.lua`: catch-up factor/cap, time constant, player
  alignment, lifetime/overtake caps, catch maximum/time constant, owned target,
  AI tier, ecology radius, rarity, and roster behavior.
- Leader counts, floors, flex pools, and strategy packages live in
  `src/data/boss_rosters.lua`.
- Elite Four floors, pools, packages, and Bird definitions live in
  `src/data/league_rosters.lua`.
- Rival attachment, scoring, time scaling, pressure limits, encounter windows,
  and canonical anchors live in `src/data/rival_windows.lua`.
- Runtime generators consume these data modules; new tuning literals must not
  be spread through generator code.

## Change rule

A future balance change needs all of the following in the same review:

1. A named gameplay problem and affected trainer identity.
2. A deterministic failing property or simulation that reproduces it.
3. The smallest data-only constant change that fixes the failure.
4. Red/Blue/Yellow, save/reload, boundary, and negative-case verification.
5. Before/after distributions recorded here, including any trade-off.

Player species or move-list countering is not an acceptable tuning mechanism.
Human review remains required for every balance-policy change.

## Unresolved simulation scope

- Phase G Steel, weather, Gold sidecar, Brock/Elite Four Kanto+ substitutions,
  and Kanto-only fallback cannot be balanced until the upstream dataset and
  field-residual seams are released and integrated.
- Full registered-party traversal remains an upstream engine regression gate,
  not a mod-side balance simulation.
- Final package and ROM-free checks are release integrity gates, not balance
  evidence.
