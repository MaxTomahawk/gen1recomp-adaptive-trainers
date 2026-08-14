# Adaptive Trainers

Adaptive Trainers is a standalone Gen1Recomp overhaul that gives ordinary trainers, Gym Leaders, the Elite Four, and the Rival deterministic persistent development across Pokémon Red, Blue, and Yellow.

The approved v1 design baseline is preserved in `Gen1Recomp_Adaptive_Trainers_Complete_Design_Spec_NL.docx`. Implementation progress and evidence are tracked in `docs/IMPLEMENTATION_STATUS.md`.

This repository is under active development; the current `0.1.0` line is not yet the stable release.

## Development

Clone the current Gen1Recomp `dev` branch outside the distributable mod and point the checks at it:

```sh
git clone --branch dev https://github.com/bryanthaboi/gen1recomp.git ../gen1recomp
GEN1RECOMP_ROOT=../gen1recomp ./scripts/check.sh
GEN1RECOMP_ROOT=../gen1recomp SOURCE_DATE_EPOCH=0 ./scripts/package.sh
```

`check.sh` runs deterministic unit/property tests and the LuaJIT public SDK
integration suites, then runs `modkit validate` and `modkit lint`. `package.sh`
repeats those gates, stages only distributable files, and writes a reproducible
`.modpkg` under `dist/`.

Phases A and B are implemented: ordinary supported trainer classes receive a
context/ecology-aware roster once, and that exact set of individuals then lives
in `mod.save`. After player losses they observe the exact grace period, grow
toward bounded contextual ceilings, may make one plausible catch per interval,
and rotate a bench only with plausible Center access. Bosses, the League, Rival
development, and the optional Kanto+ sidecar remain on the tracked implementation
path. The persistent legal-moveset foundation and evolution refresh are present
because Phase B depends on them; full sophistication-tier scoring and AI
registration remain Phase C work.

No ROM, extracted cartridge data, or ROM-derived media belongs in this repository or its release artifacts.
