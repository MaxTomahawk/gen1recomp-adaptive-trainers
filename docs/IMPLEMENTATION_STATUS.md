# Implementation status

Updated: 2026-08-25

## Objective

Implement the complete approved Adaptive Trainer Ecology & Challenge System v1 as the standalone `adaptive_trainers` Gen1Recomp mod for Red, Blue, and Yellow.

Authoritative product baseline:
`Gen1Recomp_Adaptive_Trainers_Complete_Design_Spec_NL.docx`.

Release evidence:
`docs/DEFINITION_OF_DONE_AUDIT.md`.

## Release baseline

- Engine: `bryanthaboi/gen1recomp` `v0.2.25`
- Exact engine SHA: `08121faa3dd01ba68bb6bb74676650c5ebe1d116`
- Dataset-view merge: `9dd38e06a578b0ed5e275934908fbd52e8a8c785` (#1767)
- Manifest: `adaptive_trainers` `0.1.0`, Mod API 2, `>=0.2.25 <1.0.0`
- Games: Red, Blue, Yellow
- Canonical artifact: `adaptive_trainers-0.1.0.zip`
- Published stable release: `v0.1.0`, target commit `34fca7f7ea5d8cb445131b8f6042538b3458b901`

All engine seams required by the approved design are present in the official release. The mod uses public APIs only and does not vendor engine code.

## Phase status

- [x] Phase A — deterministic identity/save/RNG and persistent context/ecology-aware standard trainers
- [x] Phase B — loss grace, bounded growth, local catches, Center-aware owned/active roster behavior
- [x] Phase C — legal persistent movesets and class-driven AI under the v0.1.0 legality model
- [x] Phase D — Gym registration UI/mask intent, eight Leader identities, fair challenge scaling and attempt persistence
- [x] Phase E — Elite Four run snapshot, stable member teams and exactly-one-Bird mechanic
- [x] Phase F — persistent Rival journey, R/B/Y paths and exact Yellow Eevee outcomes
- [x] Phase G — fail-closed optional Kanto+ sidecar, Steel, weather, selected Gold moves/assets
- [x] Phase H — deterministic developer-only diagnostics, aggregate acceptance, reproducible release packaging and release workflow

The phase checkboxes above describe the v0.1.0 implementation baseline. Manual in-game testing after publication identified corrective integrity work that is now documented separately below; those findings do not erase the historical release evidence.

## Fresh release evidence

The release candidate was validated against exact Gen1Recomp `v0.2.25`.

Representative current suite evidence includes:

- Phase A public runtime: 327/327; Phase A properties: 17,000/17,000.
- Phase B persistence: 235/235; Phase B properties: 6,363/6,363.
- Phase C moves/AI: 35/35.
- Gym runtime: 47/47; Gym registration: 33/33; Phase D bosses: 697/697; Gym properties: 86,250/86,250.
- League persistence: 147/147; League Bird simulation: 140,004 property assertions across 10,000 full runs.
- Rival version paths: 326/326; Rival fairness: 61,357/61,357.
- Aggregate A-F Definition of Done: 472/472.
- Phase G public runtime: 74/74; combined-engine Phase G: 26/26; fallback/reconciliation: 163/163; Kanto+ unit: 121/121 after real-import regressions.
- Runtime diagnostics: 82/82.
- Public loader: 13/13.
- Full exact-release ROM-free engine/no-mod parity was green in the final released-engine parity workflow.
- `modkit validate`: green.
- `modkit lint`: green with no ROM-derived content.
- Canonical package layout/reproducibility: green; package contains 39 archive entries and is independently rebuilt/byte-compared before publication.
- Task-14 release-prep CI on `79a5ccd5266771a605578fde4a3f1a6e9b5d6639`: green.
- Final release target/main commit: `34fca7f7ea5d8cb445131b8f6042538b3458b901`.
- Published `v0.1.0` asset was downloaded again after publication and passed digest/layout/manifest/ROM-private-path/`modkit validate`/`modkit lint` verification.

## Sanitized real-import acceptance

A private local acceptance used compatible Blue and Gold inputs through the official Gen1Recomp `v0.2.25` importer. No private source data was uploaded.

Final pre-release real-data acceptance: **27/27**.

It verifies a complete Gold sidecar while Blue remains active, all nine approved continuations/evolutions, required Gold moves/type data and generated asset namespace, representative standard trainer/save-reload/Rival/League/Gym paths, Kanto+ weather hooks, and zero missing sidecar requirements.

That gate found two fixture/translation mismatches which are fixed and covered:

1. real Gold `RAIN_DANCE` and `SUNNY_DAY` accuracy is 90, not 100;
2. imported Gen 2 growth-rate IDs use `GROWTH_*` and are normalized to the Gen 1 registry namespace.

Fix commit:
`218fbebe10a4af0c4ade0ead5262cef8596f4292`
(`fix: normalize Gold Kanto+ semantics`).

## Engine seam ledger

### AT-SP-001 — battle-local player-party eligibility

- State: `RELEASED_AVAILABLE`, but manual v0.1.0 gameplay exposed a possible integration/regression failure that must be re-characterized before the next release.
- Upstream: #1286, merge `97a9c0f58fe8c0adca9ee8f5c57a84ebf3d84489`
- Used for: Gym registration mask across all player-party selection/replacement paths
- Corrective plan: `docs/superpowers/plans/2026-08-25-gym-battle-participation-integrity.md`

### AT-SP-002 — charge-stage decision

- State: `RELEASED_AVAILABLE`
- Upstream: #1645, merge `a1a70540b84f58c16c1b7410a23b517a2b65dd1a`
- Public API: `battle.charge_required`
- Used for: Kanto+ Sunny Day / SolarBeam behavior

### AT-SP-003 — active-independent semantic dataset view

- State: `RELEASED_AVAILABLE`
- Upstream: #1767, merge `9dd38e06a578b0ed5e275934908fbd52e8a8c785`
- Released in: `v0.2.25`
- Public API: bounded read-only `mod.datasets` plus selected-cache generated asset paths
- Used for: optional Gold-backed Kanto+ while R/B/Y remains active

### AT-SP-004 — engine-owned field residual application

- State: `RELEASED_AVAILABLE`
- Upstream: #1766, merge `0ab4ef2755c84df38b22566570950b1a7ce36e81`
- Public API: `battle.field_residual`
- Used for: Kanto+ Sandstorm descriptors while the engine retains HP/faint/EXP/checkpoint authority

### AT-SP-005 — developer-mode signal

- State: `RELEASED_AVAILABLE`
- Upstream: #1769, merge `ff826ce01e47e523e0e265c5856cb4d7cb6d1a89`
- Public API: boolean `mod.developer`
- Used for: Phase H diagnostics activation only on developer boots

## Packaging/release state

- `v0.1.0` is published and the live release ZIP passed post-publication verification.
- CI is pinned to exact `v0.2.25` SHA for the v0.1.0 baseline.
- `scripts/package.sh` publishes only after full checks plus independent byte-reproducibility verification.
- Stable output is `.zip`, not `.modpkg`.
- `.github/workflows/release.yml` uses the same strict package path and publishes the versioned ZIP for `v*` tags.
- Release metadata, README, changelog, manifest and mod card are synchronized to `0.1.0` / `v0.2.25`.
- No ROM-derived bytes are included.

## Post-release manual-test findings

Manual play after `v0.1.0` publication produced two actionable correctness findings and one explicit non-finding:

1. **Rival Oak's Lab resource leak:** a level-5 Blue Rival Bulbasaur received SolarBeam. Root design issue: species TM/HM compatibility is currently treated as immediate moveset legality, while world/story progression is not an independent resource gate.
2. **Gym registered-party participation leak:** Brock registration allowed choosing two Pokémon from a three-member save party, but the unregistered third Pokémon was still available during battle and prevented defeat until it also fainted. The mod already passes `playerPartyIndices`; ownership must be re-characterized against exact released engine and current upstream before any fix.
3. **Brock Aerodactyl/Rhyhorn variation is not a bug:** Gym Leaders do not need to follow the player's personal species-acquisition route. Do not add an Aerodactyl progression restriction.

## Approved corrective design and agentic plans

The corrective work is documented for agentic development only. Read:

- Master design: `docs/superpowers/specs/2026-08-25-progression-challenge-integrity-design.md`
- Agent handoff/index: `docs/AGENTIC_DEV_HANDOFF_2026-08-25.md`
- P0 Gym participation: `docs/superpowers/plans/2026-08-25-gym-battle-participation-integrity.md`
- P0 Oak vanilla sanctuary: `docs/superpowers/plans/2026-08-25-oaks-lab-vanilla-sanctuary.md`
- P0 world progression/movesets: `docs/superpowers/plans/2026-08-25-world-progression-moveset-integrity.md`
- P1 progression reachability/evolutions: `docs/superpowers/plans/2026-08-25-progression-reachability-integrity.md`

Hard approved decisions include:

- hybrid TM/HM world-progression model: ordinary resources by world accessibility, unique Gym/story rewards generically only after milestone, explicit canonical-owner exceptions allowed;
- Oak's Lab starter Rival battle is completely vanilla; Adaptive Rival tactical T3 resumes at Route 22 Early;
- `tacticalTier` and `movesetTier` become separate concepts;
- Gym registration must be enforced by the battle-local party authority through switching, replacement, exhaustion, EXP/UI traversal and checkpoints;
- persistent v0.1.0 history must migrate without whole-roster reset;
- no player-species/move counter-spying and no full NPC economy simulator;
- no player-style species-acquisition gate for Brock's Aerodactyl.

## Remaining workflow

1. Execute the Gym participation integrity plan first and determine ownership on exact released engine vs current upstream.
2. Implement/test the Oak's Lab vanilla sanctuary.
3. Implement/test the World Progression Authority, TM/HM provenance, tier split, boss resource exceptions, progression refresh and v0.1.0 migration.
4. Execute the P1 reachability/evolution plan or explicitly document a deliberate deferment before the corrective release.
5. Run the complete ROM-free, reproducibility, released-engine/current-engine as applicable, R/B/Y, save/reload and real Blue+Gold acceptance gates.
6. Publish the corrective stable release only after its intended workstreams are green; `0.2.0` is the recommended pre-1.0 feature target, subject to live repository release state.
7. Hand the published release to the user for in-game testing.
8. **Do not submit or update the mod index until the user explicitly approves after testing.**
