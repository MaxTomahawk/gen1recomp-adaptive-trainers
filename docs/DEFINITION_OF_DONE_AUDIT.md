# Definition of Done audit

Updated: 2026-08-25

This ledger maps Chapter 29 and the final Definition of Done in
`Gen1Recomp_Adaptive_Trainers_Complete_Design_Spec_NL.docx` to fresh release-candidate evidence.

Release engine: `bryanthaboi/gen1recomp` `v0.2.25`
(`08121faa3dd01ba68bb6bb74676650c5ebe1d116`).

Status meanings:

- `VERIFIED` — fresh executable or artifact evidence satisfies the clause.
- `PRIVATE_VERIFIED` — satisfied with sanitized local real-import evidence; no ROM-derived data is committed or distributed.
- `PUBLICATION` — release mechanics performed after all technical gates; not a gameplay implementation requirement.

## Chapter 29 acceptance

| Acceptance area | Status | Fresh evidence |
|---|---|---|
| Same seed + identity + state => byte-equivalent party over 100 reruns | `VERIFIED` | Phase A public runtime and property suites in `scripts/check.sh` |
| Save/reload before Gym attempt preserves flex/strategy | `VERIFIED` | `phase_d_bosses_spec.lua`, `gym_runtime_spec.lua`, DoD acceptance |
| Genuine Gym loss advances attempt and can produce a different valid strategy/flex | `VERIFIED` | DoD acceptance plus 64-seed boss loss-variation simulation |
| League save/reload preserves Bird pair and member parties | `VERIFIED` | `league_persistence_spec.lua` |
| <900 seconds after loss freezes standard party | `VERIFIED` | Phase B persistence/property suites |
| Long-loss growth is bounded/monotonic and never exceeds ceilings | `VERIFIED` | growth unit/property suites |
| At most one valid non-Legendary ecology catch per interval | `VERIFIED` | catch unit/property suites |
| Collector/expert behavior differs; full party without Center access is safe | `VERIFIED` | catch/roster suites and Phase B properties |
| Initial generated team remains inside the normative power band | `VERIFIED` | Phase A property suite |
| Gym N mask is enforced through menu/switch/auto-send/exhaustion | `VERIFIED` | released-engine full ROM-free regression/no-mod parity plus mod Gym runtime/registration suites |
| Boss top-N formula, floors, signature, and player-species blindness | `VERIFIED` | Phase D runtime/property suites |
| 10,000 League runs contain exactly one allowed Bird pairing | `VERIFIED` | League Bird property simulation: 140,004 assertions |
| Rival result is player-species/move blind at equal encounter/time/levels/owned state | `VERIFIED` | Rival fairness property suite: 61,357 assertions |
| Yellow Eevee outcomes are exact | `VERIFIED` | Rival version-path integration |
| No mod enabled leaves released-engine vanilla/no-mod suites green | `VERIFIED` | full `v0.2.25` ROM-free `./scripts/test.sh` release-parity gate |
| Pre-standard-generation mod writes remain inside `mod.save` | `VERIFIED` | instrumented DoD acceptance filesystem spy |
| Mid-battle checkpoint restores authority or fails closed | `VERIFIED` | standard/Gym/League/Rival checkpoint suites |
| R/B/Y version-specific floors and Rival anchors are correct | `VERIFIED` | Phase D/F R/B/Y integration |
| Kanto+ disabled gives graceful Kanto-only fallback | `VERIFIED` | fallback/root reconciliation and Phase G runtime |
| Real imported Gold activates complete Kanto+ through public APIs | `PRIVATE_VERIFIED` | sanitized local Blue+Gold acceptance: 27/27 checks; active Blue authority preserved |

## Final product Definition of Done

| Clause | Status | Evidence |
|---|---|---|
| Loads on Red, Blue, Yellow through the public loader; disabled behavior remains vanilla | `VERIFIED` | public loader/R/B/Y suites + full released-engine no-mod regression |
| Context/ecology-aware deterministic persistent standard trainers | `VERIFIED` | Phase A |
| Grace, bounded growth, profile catches, finite scaling | `VERIFIED` | Phase B |
| Center-safe bench rotation and differentiated profiles | `VERIFIED` | Phase B |
| Data-driven legal persistent moves and class AI | `VERIFIED` | Phase C |
| Gym registration mask/top-N/signature/reroll/strategy packages | `VERIFIED` | Phase D + released-engine mask paths |
| All eight Leaders use approved pools/packages/floors | `VERIFIED` | Phase D runtime/properties |
| Elite Four snapshot/scaling and exactly one visible valid Bird | `VERIFIED` | Phase E + 10,000-run simulation |
| Rival journey/owned history/windows/attachment/core/bounded pressure and species blindness | `VERIFIED` | Phase F + fairness properties |
| Exact Yellow Eevee path | `VERIFIED` | Phase F version paths |
| Legendary exclusions and population/instance model | `VERIFIED` | data/catch/standard/League/Rival suites |
| Optional Kanto+; core works without Gold; Steelix/Steel/weather work with compatible Gold | `PRIVATE_VERIFIED` | Phase G fixture suites + 27/27 real Blue+Gold acceptance |
| Dev-only observability without production leakage | `VERIFIED` | Phase H runtime diagnostics through public `mod.developer` |
| Chapter 29 tests, validate/lint, reproducible package, no ROM-derived bytes | `VERIFIED` | canonical `scripts/package.sh`, strict staging, independent SHA comparison, lint/content gate |
| Central fantasy remains persistent people rather than per-battle randomization | `VERIFIED` | final design/implementation review: standard trainers persist; bosses reroll only on genuine challenge attempts; Rival/League maintain independent persistent authorities |

## Real-import boundary

The sanitized real-import gate used the official `v0.2.25` importer for a compatible Blue and Gold dataset in an isolated local identity. No ROM, imported cache, generated private data, machine path, or ROM-derived asset was sent to GitHub or included in an artifact.

The gate proved:

- active Blue game/cache authority did not change when opening Gold;
- `mod.datasets:open("gold")` exposed the expected bounded semantic dataset;
- all nine approved continuations, evolutions, required moves/type data and generated asset paths admitted cleanly;
- Kanto+ weather/charge/residual paths activated through public APIs;
- representative standard trainer, save/reload, Rival, League, and Brock/Gym paths remained clean;
- Kanto+ produced zero missing requirements and zero loader errors.

The real dataset exposed and fixed two pre-release fixture mismatches: Gold reports Rain Dance/Sunny Day accuracy as 90, and Gen 2 growth-rate IDs use a `GROWTH_*` namespace. Both now have deterministic regression coverage.

## Packaging and publication boundary

The canonical distributable is `adaptive_trainers-0.1.0.zip`.

`scripts/package.sh` is fail-closed: it runs the full project gate, stages through
`scripts/package_once.sh`, verifies archive layout, independently rebuilds a
second archive with the same `SOURCE_DATE_EPOCH`, compares SHA-256, and only
then publishes the accepted file under `dist/`.

The release workflow checks out exact Gen1Recomp `v0.2.25`, rejects a
tag/manifest version mismatch, invokes the same canonical package path, and
uploads only `dist/adaptive_trainers-0.1.0.zip`.

Publication is allowed only after the final release-candidate CI is green. The
published ZIP is then downloaded and re-inspected before the release is handed
to the user for in-game testing. Mod-index submission is intentionally outside
this release gate and requires the user's post-test approval.
