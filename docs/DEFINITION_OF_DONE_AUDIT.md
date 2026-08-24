# Definition of Done audit

Updated: 2026-08-24

This ledger maps the normative Definition of Done and Chapter 29 in
`Gen1Recomp_Adaptive_Trainers_Complete_Design_Spec_NL.docx` to executable
evidence. It deliberately separates completed A-F behavior from Phase G,
upstream-release, runtime-observability, packaging, and publication gates.

Status meanings:

- `VERIFIED_A_F` — executable evidence exists in the current mod tree.
- `PARTIAL` — part of the clause is executable, but a named gate remains.
- `BLOCKED_PHASE_G` — the optional Kanto+ implementation or its upstream seam
  is not on `main`.
- `PENDING_RELEASE` — meaningful only against the final merged tree and released
  engine dependency.

## Chapter 29 executable evidence

| Normative acceptance area | Status | Executable evidence |
|---|---|---|
| Same seed, identity, and state produce byte-equivalent parties over 100 reruns | `VERIFIED_A_F` | `tests/integration/phase_a_mod_spec.lua`; `tests/property/phase_a_properties_spec.lua` |
| Standard-trainer save/reload persistence | `VERIFIED_A_F` | `tests/integration/phase_a_mod_spec.lua`; `tests/integration/phase_b_persistence_spec.lua` |
| Gym save/reload and genuine-loss attempt advancement | `VERIFIED_A_F` | `tests/integration/phase_d_bosses_spec.lua`; `tests/integration/gym_runtime_spec.lua`; `tests/acceptance/definition_of_done.lua` |
| A loss can produce a different valid Gym strategy or flex roster | `VERIFIED_A_F` | `tests/acceptance/definition_of_done.lua` checks attempts zero and one across 64 fixed seeds while rechecking size, signature, and target levels |
| League run, Bird pair, member seeds, and parties survive reload | `VERIFIED_A_F` | `tests/integration/league_persistence_spec.lua` |
| Exact 900-second grace and bounded monotonic long-loss growth | `VERIFIED_A_F` | `tests/integration/phase_b_persistence_spec.lua`; `tests/unit/growth_spec.lua`; `tests/property/phase_b_properties_spec.lua` |
| At most one ecological non-Legendary catch per interval | `VERIFIED_A_F` | `tests/unit/catch_spec.lua`; `tests/property/phase_b_properties_spec.lua` |
| Collector/expert differentiation and full-party bench safety | `VERIFIED_A_F` | `tests/unit/catch_spec.lua`; `tests/property/phase_b_properties_spec.lua` |
| Initial party remains within the normative power band | `VERIFIED_A_F` | `tests/property/phase_a_properties_spec.lua` |
| Gym N, top-N formula, floors, signature, structure, and player-species blindness | `VERIFIED_A_F` | `tests/integration/phase_d_bosses_spec.lua`; `tests/property/gym_properties_spec.lua` |
| Registered Gym mask is preserved through public battle state | `PARTIAL` | Mod lifecycle: `tests/integration/gym_runtime_spec.lua`. Final audit must rerun the upstream menu, switch, auto-send, exhaustion, checkpoint, and no-mod suites against the released engine SHA. |
| Ten-thousand-run exactly-one-Bird distribution | `VERIFIED_A_F` | `tests/property/league_bird_simulation_spec.lua` |
| Rival species/move blindness, journey persistence, and R/B/Y anchors | `VERIFIED_A_F` | `tests/property/rival_fairness_spec.lua`; `tests/integration/rival_version_paths_spec.lua` |
| Exact Yellow Eevee outcomes | `VERIFIED_A_F` | `tests/integration/rival_version_paths_spec.lua` |
| Disabled mod leaves vanilla behavior unchanged | `PARTIAL` | Focused public-loader evidence exists in `tests/integration/phase_a_mod_spec.lua`. The final gate is the complete upstream no-mod suite at the release SHA. |
| No load/pre-standard-generation writes outside `mod.save` | `VERIFIED_A_F` | `tests/acceptance/definition_of_done.lua` installs its filesystem spy before SDK discovery/load, attributes `mod_storage/` and legacy `mod_compat/` writes to the loaded mod while excluding engine-owned loader bookkeeping, proves both persistence paths are detectable and unused, preserves another mod namespace, and proves an unmapped class creates no trainer state. |
| Mid-battle checkpoint restores the correct authority or fails closed | `VERIFIED_A_F` | `tests/integration/phase_b_persistence_spec.lua`; `tests/integration/gym_runtime_spec.lua`; `tests/integration/league_persistence_spec.lua`; `tests/integration/rival_version_paths_spec.lua` |
| R/B/Y boss floors and Rival anchors | `VERIFIED_A_F` | `tests/integration/phase_d_bosses_spec.lua`; `tests/unit/rival_spec.lua`; `tests/integration/rival_version_paths_spec.lua` |
| Kanto-only fallback without Gold identifiers | `BLOCKED_PHASE_G` | Phase G implementation and its dataset-view/field-residual release gates remain unresolved. |

`scripts/check.sh` discovers `tests/acceptance/*.lua` in addition to every
`*_spec.lua`. The acceptance executable reruns the representative A-F Chapter
29 suites in isolated Lua processes, preventing shared runtime registrations
from turning the ledger into a source-text assertion.

## Full normative Definition of Done

| Definition of Done clause | Status | Evidence or remaining gate |
|---|---|---|
| Public R/B/Y loader and no behavior when disabled | `PARTIAL` | Public loader evidence is green; full released-engine no-mod parity remains. |
| Deterministic persistent context/ecology-aware standard trainer | `VERIFIED_A_F` | Phase A runtime and property suites. |
| Grace, saturating growth, profile catches, and finite scaling | `VERIFIED_A_F` | Phase B unit, integration, and property suites. |
| Center-safe bench rotation and differentiated trainer profiles | `VERIFIED_A_F` | Catch/roster unit tests and Phase B properties. |
| Data-driven legal persistent moves and class AI | `VERIFIED_A_F` | Phase C runtime, unit, and property suites. |
| Gym N/mask/top-N/signature/reroll/structural packages | `PARTIAL` | Mod behavior is green; final released-engine mask-path parity remains. |
| All eight Leaders have named pools, packages, and floors | `VERIFIED_A_F` | Phase D runtime and Gym properties. |
| Elite Four snapshot/scaling and one visible valid Bird | `VERIFIED_A_F` | Phase E runtime and 10,000-run simulation. |
| Rival owned history, windows, attachment, core, bounded pressure, and no species countering | `VERIFIED_A_F` | Phase F runtime, core, and fairness properties. |
| Exact Yellow Eevee path | `VERIFIED_A_F` | Phase F R/B/Y integration. |
| Legendary exclusions and population model | `VERIFIED_A_F` | Data, catch, standard, League, and Rival properties. |
| Optional Kanto+ with graceful base fallback, Steelix, weather, and Steel | `BLOCKED_PHASE_G` | AT-SP-003 is under review and AT-SP-004 is not merged/released. |
| Every Chapter 29 test, validate/lint, and no ROM-derived bytes | `PENDING_RELEASE` | A-F aggregate exists; final G/H tree, released engine SHA, ROM scan, and double-package evidence remain. |
| Central trainer identity and gameplay fantasy remain legible | `PARTIAL` | Existing README/design describe the identity; final gameplay review belongs to the complete G/H build. |

## Observability boundary

`src/core/diagnostics.lua` provides deterministic, detached, whitelisted
projections for standard trainers, bosses, League, and Rival state. It exposes
the normative seed/choice labels without player names, the player's roster, or
unknown save fields. Nested supplied evidence is recursively detached while
functions, userdata, threads, metatables, cycles, NaN, and infinities are
omitted. The adapter reports every declared A-F projection choice with stable
seed labels, parts, and values; it does not claim to observe runtime events.
`src/ui/debug.lua` emits nothing unless its injected environment contains the
exact string `POKEPORT_DEV=1`.

The current public mod sandbox intentionally does not expose the host
environment or an equivalent `mod.dev` flag. The adapter is therefore tested
and package-ready but is not wired to a production-visible screen or export.
Runtime activation requires either an approved public dev-mode seam or an
engine-owned dev-screen integration; using the legacy `os.getenv` compatibility
shim would add warnings and violate the clean public-API target.

## Release gates still open

1. Merge/release AT-SP-003 and AT-SP-004, then integrate and verify Phase G.
2. Resolve a public dev-only activation surface for the diagnostic adapter.
3. Pin CI and `manifest.json` to the released engine containing every required
   seam.
4. Run the complete upstream no-mod and relevant public-API regression suites.
5. Run the final R/B/Y, Kanto-only, Kanto+, validation, lint, ROM scan, and
   byte-identical double-package gates.
6. Review the final gameplay identity, update release metadata, and follow the
   then-current mod-index process.
