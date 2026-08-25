# Adaptive Trainers

Adaptive Trainers is a standalone Gen1Recomp overhaul for Pokémon Red, Blue, and Yellow. Ordinary trainers become persistent individuals that develop over time, while Gym Leaders, the Elite Four, and the Rival use distinct deterministic challenge systems.

## Requirements

- Gen1Recomp **v0.2.25 or newer** (`>=0.2.25 <1.0.0`)
- Mod API 2
- Pokémon Red, Blue, or Yellow

The approved v1 design baseline is `Gen1Recomp_Adaptive_Trainers_Complete_Design_Spec_NL.docx`. Implementation and release evidence are tracked in `docs/IMPLEMENTATION_STATUS.md` and `docs/DEFINITION_OF_DONE_AUDIT.md`.

## Install

Download `adaptive_trainers-0.1.0.zip` from the GitHub Release and install it through Gen1Recomp's normal mod installation flow.

The distributable ZIP contains only the mod manifest, card, entrypoint, runtime source, documentation needed by the installed mod, and allowed assets. It contains no ROM or ROM-derived data.

## What v0.1.0 does

- Gives supported ordinary trainers deterministic, context/ecology-aware persistent rosters.
- Applies loss-gated grace, bounded growth, plausible catches, Center-aware bench rotation, persistent legal moves, and class-driven AI.
- Turns Gym Leaders into registered-party challenges with version-correct party sizes, top-N level matching, fixed signature lines, structural strategy packages, and persistent attempts.
- Keeps one persistent Elite Four run snapshot with stable member teams and exactly one run-specific Articuno, Zapdos, or Moltres pairing.
- Gives the Rival an independent persistent journey across all Red/Blue/Yellow canon encounters, including the exact Yellow Eevee outcomes.
- Provides developer-only deterministic diagnostics through the public `mod.developer` boundary.
- Supports an optional fail-closed **Kanto+** sidecar using the public imported-dataset API.

## Kanto+

Kanto+ is optional. The core mod works without a Gold import.

When a compatible Pokémon Gold dataset has already been imported by Gen1Recomp, Adaptive Trainers can use the public read-only dataset view to enable the approved nine Kanto-line continuations, Steel/type data, selected Gold moves and generated sprite paths, plus the Kanto+ weather behavior.

If that capability is unavailable, incomplete, or invalid, Kanto+ stays disabled and the mod reconciles safely to Kanto-only behavior. Adaptive Trainers does not read raw ROM bytes, execute generated Lua, change the active game, or reinterpret a ROM itself.

## Development

Use the exact supported engine release for release validation:

```sh
git clone --branch v0.2.25 https://github.com/bryanthaboi/gen1recomp.git ../gen1recomp
GEN1RECOMP_ROOT=../gen1recomp ./scripts/check.sh
GEN1RECOMP_ROOT=../gen1recomp SOURCE_DATE_EPOCH=0 ./scripts/package.sh
git diff --check
git status --short
```

`check.sh` runs deterministic unit/property/integration/acceptance coverage, then `modkit validate` and `modkit lint`. `package.sh` repeats the complete gate, stages only distributable files, verifies archive layout, creates an independent second package, compares SHA-256 hashes, and only then publishes `dist/adaptive_trainers-0.1.0.zip`.

No ROM, extracted cartridge data, generated private cache, or ROM-derived media belongs in this repository or its release artifacts.
