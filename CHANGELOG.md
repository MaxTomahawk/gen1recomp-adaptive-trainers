# Changelog

All notable changes to this project are documented in this file.

The format follows Keep a Changelog, and this project uses Semantic Versioning.

## [Unreleased]

## [0.1.0] - 2026-08-25

### Added

- Deterministic per-save RNG streams, concrete trainer identities, persistent standard-trainer rosters, save/reload support, and checkpoint-safe authority reconstruction.
- Context/ecology-aware roster generation with Kanto evolution-line metadata, trainer-class profiles, rarity/specialist constraints, bounded invariant repair, and player-loss grace.
- Loss-gated saturating growth, plausible local catches, Center-aware owned/active roster management, collector/expert differentiation, and finite contextual ceilings.
- Persistent legality-aware movesets, move-source memory, class-driven AI scoring, teammate fit, and bounded tactical switching.
- Eight version-correct Gym Leader challenge systems with registered-party masks, top-N scaling, vanilla floors, fixed signatures, structural strategy packages, flex rerolls after genuine losses, and battle-scoped expert AI.
- Persistent Elite Four runs with immutable top-five entry snapshots, reload-stable adaptive teams, Hall-of-Fame lifecycle handling, and exactly one valid run-specific Legendary Bird pairing.
- Persistent Rival journey across every Red, Blue, and Yellow canon encounter with deterministic route-window acquisitions, owned-roster training/evolution, attachment-driven rotation, bounded pressure, and exact Yellow Eevee outcomes.
- Developer-only deterministic diagnostics for trainer, boss, League, and Rival decisions through the public `mod.developer` signal.
- Optional fail-closed Kanto+ support through public imported dataset views, including the nine approved Kanto-line continuations, Steel/type data, selected Gold moves/sprites, weather, SolarBeam charge behavior, and engine-owned Sandstorm residual handling.
- Reproducible fail-closed packaging to `adaptive_trainers-0.1.0.zip`, strict distributable staging, archive-layout checks, independent double-build SHA comparison, and a tag-driven GitHub Release workflow.

### Changed

- Minimum supported Gen1Recomp version is `v0.2.25`.
- CI is pinned to the exact audited `v0.2.25` engine SHA and runs one complete package gate per lane.

### Fixed

- Match real Pokémon Gold semantics for `RAIN_DANCE` and `SUNNY_DAY` accuracy.
- Normalize imported Gen 2 `GROWTH_*` identifiers into the Gen 1 registry namespace before Kanto+ species registration.
