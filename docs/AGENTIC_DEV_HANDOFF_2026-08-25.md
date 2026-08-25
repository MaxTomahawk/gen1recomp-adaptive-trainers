# Agentic Development Handoff — Progression & Challenge Integrity

> **Audience:** future coding/review agents. Not player-facing.
>
> **Date:** 2026-08-25
>
> **Starting point:** `main` at v0.1.0 release commit `34fca7f7ea5d8cb445131b8f6042538b3458b901` when this documentation set was authored.

## 1. Why this handoff exists

Real in-game testing of v0.1.0 exposed two correctness classes that the original deterministic suite did not adequately constrain:

1. a level-5 Rival Bulbasaur in Oak's Lab could receive a powerful future TM move because species TM/HM compatibility was treated as immediate legality;
2. a Brock Gym registration that selected only two of three player Pokémon still allowed the unregistered third Pokémon to participate and delayed defeat until all three were fainted.

The human owner then approved a broader progression-integrity design rather than isolated symptom patches.

This handoff is the entry point for that work.

## 2. Normative document order

Read in this order before implementation:

1. repository `AGENTS.md` — current repository process and upstream contribution rules;
2. current upstream Gen1Recomp mod-contribution policy/docs if any engine work is contemplated;
3. `docs/superpowers/specs/2026-08-25-progression-challenge-integrity-design.md` — approved behavior/architecture;
4. the relevant implementation plan below;
5. existing complete design spec `Gen1Recomp_Adaptive_Trainers_Complete_Design_Spec_NL.docx` for all unaffected mechanics;
6. current `docs/IMPLEMENTATION_STATUS.md`, `docs/DEFINITION_OF_DONE_AUDIT.md`, and `docs/BALANCING.md` for historical evidence.

If a current upstream policy conflicts with a historical engine instruction, current upstream policy wins for engine contribution mechanics. If a planned implementation detail conflicts with the approved behavior in the new design spec, the design spec wins and the plan must be amended before code proceeds.

## 3. Approved workstreams and execution order

### Workstream 1 — Gym battle participation integrity — P0

Plan:

`docs/superpowers/plans/2026-08-25-gym-battle-participation-integrity.md`

Purpose:

- reproduce the observed 3->2 Brock registration leak;
- prove whether ownership is mod-side, released-engine-only, or current upstream engine;
- enforce the existing public `playerPartyIndices` contract through manual switch, Shift prompt, forced replacement, exhaustion, EXP traversal, battle UI and checkpoint restore;
- never mutate `game.save.party` as a workaround.

This workstream is first because it may require an upstream engine correction/release and therefore can become the longest external dependency.

### Workstream 2 — Oak's Lab vanilla sanctuary — P0

Plan:

`docs/superpowers/plans/2026-08-25-oaks-lab-vanilla-sanctuary.md`

Purpose:

- make the first Rival battle completely vanilla;
- do not replace global Rival T3 with T0/T1;
- bypass Adaptive party/moves/AI transformation only for `OAK_LAB`;
- continue observing the result for Red/Blue starter continuity and Yellow Eevee outcome history;
- resume normal Adaptive Rival behavior at `ROUTE_22_EARLY`.

### Workstream 3 — World progression & moveset integrity — P0

Plan:

`docs/superpowers/plans/2026-08-25-world-progression-moveset-integrity.md`

Purpose:

- add one World Progression Authority;
- add complete TM/HM provenance and the approved hybrid unlock model;
- separate `tacticalTier` from `movesetTier`;
- make boss move exceptions explicit;
- add progression-epoch refresh;
- migrate v0.1.0 move provenance without resetting trainers;
- expose sanitized developer diagnostics.

This is the architectural correction that prevents the Oak SolarBeam class of bug elsewhere.

### Workstream 4 — Progression reachability & evolution integrity — P1

Plan:

`docs/superpowers/plans/2026-08-25-progression-reachability-integrity.md`

Purpose:

- add resource plausibility to non-level/surrogate evolutions;
- make known ecology barriers progression-aware;
- stage organization-issued acquisition pools;
- preserve boss/rare-species identity exceptions.

This may be deferred from the first corrective release if Workstreams 1-3 are complete and the deferment is explicitly documented. It must not be silently treated as complete.

## 4. Hard product decisions

Do not reopen these without explicit human review:

### TM/HM progression

Use the hybrid model:

- ordinary/repeatable resource -> world accessibility;
- unique Gym/story reward -> milestone completion for generic NPC access;
- canonical owner/awarder -> explicit identity exception allowed before generic unlock.

Do **not** key availability to whether the player personally owns or taught the move.

### Oak's Lab

Oak's Rival battle is a hard vanilla sanctuary. No Adaptive moves, levels, roster or tactical override. Observe result only.

### Rival intelligence

Route 22 Early and later Rival encounters may remain tactical T3. Tactical intelligence must not imply access to future resources.

### Gym registration

If two Pokémon are registered, only those two exist for that battle's player-party view. The third may remain healthy in the real save and must still be unavailable. Exhausting the two registered Pokémon means loss.

### Boss species progression

Do not impose the player's species-acquisition timeline on Gym Leaders/experts.

**Specifically: no task should restrict Brock's Aerodactyl.** The observed Aerodactyl/Rhyhorn variation is valid boss-pool behavior, not a progression bug.

### Player privacy/fairness

Do not inspect player species or player move lists to counter-pick trainer resources. Existing approved level-scaling inputs remain separate.

### No NPC economy simulation

Do not add money, shopping trips, per-NPC consumable TM inventory or other economy simulation. Model plausible availability/provenance only.

## 5. Required Superpowers workflow

Before coding any workstream:

1. use `superpowers:using-git-worktrees` or equivalent approved isolated workspace process;
2. use `superpowers:test-driven-development` for each behavior change;
3. use `superpowers:systematic-debugging` for the observed Gym leak or any unexplained failure;
4. execute the relevant written plan via `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans`;
5. use `superpowers:verification-before-completion` before claiming a task/workstream is done;
6. request code review for meaningful workstream boundaries.

Do not combine all workstreams into one giant production commit.

## 6. Engine ownership rule for the Gym bug

Adaptive Trainers v0.1.0 already passes selected Gym indices through the public `trainer.before_battle` continuation. The documented Gen1Recomp party-scope contract says those indices govern the complete battle-local player-party view.

Therefore:

- reproduce on the exact released engine required by the mod;
- reproduce on current upstream `dev`;
- prove which layer loses the scope before changing code.

Possible outcomes:

```text
release fails, dev passes       -> wait for/require released engine containing fix; update floor if needed
release fails, dev fails        -> generic upstream engine regression; fix via live contribution policy
release passes, mod path fails  -> mod invocation/state bug; fix mod
```

Forbidden workaround:

```text
temporary save.party mutation
```

The engine seam was designed specifically to avoid that.

## 7. Release policy for the corrective work

Recommended semantic target is `0.2.0` because the work changes core resource/progression interpretation and Gym challenge correctness. The executing agent must still inspect current repository versioning/release state before changing the manifest.

A corrective release is blocked until all intended P0 workstreams are green through:

- focused TDD tests;
- full ROM-free `./scripts/check.sh`;
- reproducible `./scripts/package.sh` with `SOURCE_DATE_EPOCH=0`;
- current Gen1Recomp validation/lint requirements;
- Red/Blue/Yellow deterministic coverage;
- save/reload and legacy-state migration coverage;
- real Blue + Gold sidecar acceptance through public APIs;
- Gym 3->2 real-game acceptance;
- Oak vanilla real-game acceptance.

If Workstream 1 requires a new upstream engine release, do not publish a mod release that claims the Gym contract fixed until the required engine version is publicly released and the manifest version floor is correct.

## 8. Mod-index gate

The v0.1.0 mod-index submission was intentionally not performed because manual player testing was still in progress.

For the corrective release, preserve the same human gate:

> Do not submit/update the mod-index listing until the human owner manually tests the release and explicitly approves mod-index submission.

Do not infer approval from successful automated acceptance.

## 9. Evidence discipline

For every completed workstream, update the existing evidence docs with:

- exact mod commit;
- exact engine tag/SHA;
- focused RED evidence for the reproduced bug/requirement;
- focused GREEN evidence;
- full gate result;
- real-data acceptance scenario names;
- any upstream PR/release dependency;
- known deferred scope.

Keep private ROM/cache paths and raw derived content out of committed logs/docs.

## 10. Agent stop conditions

Stop and ask for human/maintainer action only when one of these is true:

1. an upstream engine PR must be reviewed/merged/released before the mod can honestly proceed;
2. a required public API does not exist and current policy requires an upstream design decision;
3. a real-game acceptance result contradicts the approved design and cannot be resolved without changing product behavior;
4. a private-ROM/manual acceptance step cannot be performed in the available environment;
5. a spec contradiction remains after rereading both the new design and original approved design.

Do **not** stop for routine implementation choices already specified in the plans.

## 11. Definition of success

A future corrective release is successful when:

- a surprising generated move can always be explained by vanilla/world progression or an explicit trainer/Kanto+ exception;
- tactical T3 cannot manufacture future resources;
- Oak's Lab is genuinely vanilla;
- Gym registration is enforced by battle authority, not just the UI;
- persistent v0.1.0 trainer/Rival history survives migration;
- boss identity remains expressive without being forced onto the player's collection timeline;
- the package remains ROM-free, deterministic and reproducible;
- the human owner can test the published build before any mod-index action.