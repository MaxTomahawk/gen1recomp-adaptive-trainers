# Progression & Challenge Integrity Design

> **Audience:** agentic developers only. This document is normative implementation guidance for future work in `gen1recomp-adaptive-trainers`; it is not player-facing documentation.
>
> **Status:** approved design direction as of 2026-08-25. The existing complete design spec remains authoritative except where this document explicitly tightens or clarifies progression, Rival Oak's Lab behavior, and Gym battle participation.

## 1. Purpose

Adaptive Trainers v0.1.0 proved the core trainer ecology, persistence, Rival, Gym, League, AI, Kanto+ and packaging systems, but real in-game testing exposed two classes of integrity gaps:

1. **Progression legality can be technically valid but fictionally impossible.** A species-compatible TM currently enters the moveset pool as soon as the species data lists it, even if the vanilla world has not made that TM reasonably obtainable yet. A level-5 Rival Bulbasaur in Oak's Lab can therefore receive SolarBeam even though the move should not exist in that encounter's resource context.
2. **Challenge registration can be visually correct while battle participation is not actually scoped.** The Gym registration UI can let the player select only two Pokémon, yet an observed Brock battle still allowed switching to an unregistered third Pokémon and only declared defeat after all three fainted.

The goal of this design is to restore a single principle across the mod:

> **Adaptive Trainers may make opponents smarter, more persistent and more varied, but every generated capability must be justified by either vanilla world progression, trainer identity, or an explicit approved challenge exception. UI restrictions must be enforced by the battle authority, not merely displayed.**

## 2. Explicit product decisions

These are hard requirements, not tuning suggestions.

### 2.1 Hybrid world-progression model for TM/HM resources

Use the approved hybrid model:

- **Ordinary/repeatable resources** become available when the relevant part of the vanilla world is reasonably accessible.
- **Unique Gym/story rewards** become generically available only after the corresponding milestone is complete.
- **The NPC that canonically owns or awards a unique technique may use an explicit identity-scoped exception before the player has earned that reward.**
- NPC access must never be keyed to whether the player personally picked up, purchased, taught, or currently owns a move.

This means the world state, not the player's private inventory choices, is the authority.

### 2.2 Oak's Lab is a vanilla sanctuary

The first Rival battle in Oak's Lab must be completely vanilla from the battle-system perspective:

- vanilla Rival starter species/path;
- vanilla level;
- vanilla moves;
- vanilla battle AI behavior;
- vanilla player-party behavior;
- no Adaptive moveset generation;
- no Adaptive tactical tier override;
- no Adaptive level scaling;
- no Adaptive roster substitution;
- no Kanto+ additions;
- no generated TM/technique access.

Adaptive Trainers may **observe and persist the battle result** because Yellow's Rival branch and later Rival journey state depend on it. The mod must not transform the encounter itself.

From `ROUTE_22_EARLY` onward, the normal Adaptive Rival system resumes. The Rival may again use tactical tier 3, but only within the new progression-legal moveset resource pool.

### 2.3 Gym registration is a hard battle-participation contract

If a Gym challenge allows `N` registered Pokémon and the player selects indices `{i1, ..., iN}`, then for that trainer battle the engine-visible player party is exactly that ordered subset.

Unregistered save-party members must not:

- appear in the voluntary switch menu;
- appear in Shift-style replacement prompts;
- be chosen by forced replacement;
- be auto-sent after a faint;
- count toward exhaustion/blackout detection;
- receive participation/EXP traversal as if they were in battle;
- appear as available battle-party balls;
- become available after checkpoint save/restore.

The real save party must remain unchanged. This must remain a **battle-local view**, never a temporary rewrite of `game.save.party`.

If all registered Pokémon faint, the Gym battle is lost even when unregistered party members remain healthy outside the battle.

### 2.4 Aerodactyl is explicitly out of scope

Do **not** add a player-style acquisition gate to Brock's Aerodactyl or to Gym Leader species pools merely because the player could not yet own that species through ordinary progression.

Gym Leaders, organizations, experts, collectors and bosses do not have to follow the player's exact acquisition route. Rare or unusual species can be part of an explicit trainer identity. The progression system in this design governs **resource plausibility and accidental technical leakage**, not a universal rule that every NPC must obey the player's collection timeline.

Observed variation between Brock's Aerodactyl and Rhyhorn is therefore not a defect to correct.

## 3. Core architectural distinction

The current code uses `aiTier` for more than one conceptual concern. This design separates three axes:

### 3.1 Tactical intelligence

` tacticalTier ` controls in-battle decision quality:

- move evaluation;
- switching willingness;
- advanced team-aware battle choices;
- boss/expert behavior.

It answers: **"How intelligently does this trainer use what they have?"**

### 3.2 Moveset sophistication

` movesetTier ` controls how refined a generated moveset may be:

- TM-slot budget;
- redundancy avoidance;
- coverage ambition;
- role composition;
- signature-package integration.

It answers: **"How optimized is this trainer's preparation?"**

### 3.3 World-resource availability

` worldProgression ` controls what resources exist in the trainer's plausible world context:

- TM/HM availability;
- unique reward milestones;
- evolution-resource plausibility;
- story-gated ecology reachability;
- organization-specific resource windows.

It answers: **"What could this trainer reasonably have access to at this point?"**

These axes compose in order. Tactical intelligence must never create a resource that world progression rejected.

## 4. World Progression Authority

Create one focused authority module rather than scattering badge checks through generators.

Recommended files:

- `src/core/world_progression.lua` — pure queries and snapshot normalization;
- `src/data/world_progression.lua` — Red/Blue/Yellow milestones, areas, resource sources and ordering;
- `src/data/tm_progression.lua` — TM/HM provenance records;
- optional later `src/data/evolution_progression.lua` — non-level evolution resource classes when P1 work begins.

### 4.1 Progression snapshot

A normalized snapshot should contain only information that is legitimate world state, for example:

```lua
{
  version = "blue",
  badgeCount = 2,
  milestones = {
    BROCK_DEFEATED = true,
    MISTY_DEFEATED = true,
    SS_ANNE_ACCESS = true,
  },
  areas = {
    PEWTER_CITY = true,
    CERULEAN_CITY = true,
    ROUTE_24 = true,
  },
  epoch = 5,
}
```

The exact public save fields must be derived from current Gen1Recomp public data/events at implementation time. Do not read raw ROM, raw cache, private engine state or machine-specific paths.

### 4.2 Monotonicity

Progression must be monotone for the purposes of trainer resources. Once a milestone/resource becomes available, ordinary save/load or revisiting earlier maps must not make it unavailable.

Store only the minimal derived state needed for deterministic refresh and migration. Prefer recomputing from authoritative save state when possible; persist an `epoch` or last-observed progression fingerprint only when required to decide whether a trainer deserves a refresh.

### 4.3 No player spying

World progression may use story/badge/area state. It must not inspect the player's current species or move list to choose counters.

Player levels may continue to influence already-approved level-scaling systems. That is separate from move/resource legality.

## 5. TM/HM provenance model

Every generated TM/HM candidate needs a provenance record instead of the current binary source label `"tm"`.

Recommended normalized shape:

```lua
{
  moveId = "THUNDERBOLT",
  machine = "TM24",
  class = "gym_reward",
  sourceId = "LT_SURGE_REWARD",
  availability = {
    kind = "milestone",
    id = "LT_SURGE_DEFEATED",
  },
}
```

Resource classes:

- `store_repeatable`
- `field_pickup`
- `limited_pickup`
- `gym_reward`
- `story_reward`
- `hm`
- `identity_exception`
- `kanto_plus_exception`

### 5.1 Legal-pool pipeline

The candidate pipeline becomes:

1. move exists in runtime registry;
2. species compatibility permits it;
3. source provenance is known;
4. world progression permits the source, **or** an explicit identity/package exception permits it;
5. moveset tier permits another move of that resource class;
6. scoring ranks the remaining legal candidates.

`movesets.legal_pool` must stop treating `speciesDef.tmhm` as automatically legal.

### 5.2 Provenance must survive persistence

Generated instances should be able to explain where a move came from. Replace ambiguous persistence such as:

```lua
moveSources["THUNDERBOLT"] = "tm"
```

with a versioned provenance representation, for example:

```lua
moveSources["THUNDERBOLT"] = {
  kind = "tm",
  machine = "TM24",
  sourceId = "LT_SURGE_REWARD",
}
```

A compact string representation is acceptable if deterministic and fully documented. The key requirement is that migration and diagnostics can distinguish:

- level-up;
- inherited/vanilla;
- ordinary TM;
- boss technique;
- identity exception;
- Kanto+ technique.

## 6. Boss technique policy

Bosses remain intentionally special. The new world-progression system must not flatten them into standard trainers.

Each technique in Gym/League strategy data must have one of these justifications:

1. **normal world-legal resource** — governed by the same progression source as ordinary trainers;
2. **canonical/signature exception** — explicitly scoped to that Leader/member identity;
3. **approved adaptive boss exception** — an intentional challenge technique recorded in boss data;
4. **Kanto+ exception** — requires Kanto+ capability and its design conditions.

A package entry must never silently bypass legality merely because `moveDefs[moveId]` exists.

This is especially important for early bosses whose strategy tables contain late or unusual techniques. The correct response is not necessarily to remove them; it is to make the exception explicit and reviewable.

## 7. Progression-aware moveset refresh

Persistent trainers created early must be able to benefit from later world unlocks without becoming unstable reroll machines.

Add a monotone progression marker to generated trainer/Rival state, such as:

```lua
lastMovesetProgressionEpoch = 4
```

When the world advances to epoch `5`, a trainer may receive **at most one controlled progression refresh** at the next existing safe materialization boundary.

Rules:

- never reroll during an active battle;
- no refresh merely from save/reload;
- preserve legal existing moves;
- replace only when the existing refresh algorithm's score/margin rules permit it, except migration of proven-illegal generated resources;
- do not repeatedly refresh at the same epoch;
- record the reason (`"progression"`) deterministically.

The progression refresh is additive to existing `level-up` and `evolution` refresh reasons.

## 8. v0.1.0 save migration

The new system must accept v0.1.0 save state without resetting trainer identity or journey history.

Migration rules:

- keep identity keys, battle counts, loss counts, acquired Pokémon, levels, attachment, Rival journey state, League state and boss attempt counters;
- preserve level-up and known vanilla/inherited moves whenever possible;
- inspect only generated moves whose provenance can be reconstructed;
- replace a move only when it is demonstrably impossible under the new progression rules for the recorded/current progression state;
- replacement must be deterministic and use the normal legal-pool/scoring path;
- stamp the migrated state with the new schema/provenance version;
- repeated load of an already-migrated save must be idempotent.

Do not perform a whole-roster regeneration as a migration shortcut.

## 9. Oak's Lab integration details

The mod currently needs Oak's battle result for Rival state, especially Yellow. The correct split is:

- **before/party hooks:** bypass Adaptive Rival transformation for encounter `OAK_LAB`;
- **AI context:** return no Rival tactical override for `OAK_LAB`;
- **after/result observation:** continue recording the vanilla result into Rival history;
- **first adaptive build:** ensure the persistent Rival starter/journey created for later encounters remains consistent with the observed vanilla starter and outcome.

Tests must prove that disabling transformation does not break Yellow Eevee outcome inference or Red/Blue starter continuity.

## 10. Gym battle participation integrity

Adaptive Trainers already passes `playerPartyIndices` through the public `trainer.before_battle` continuation. The public Gen1Recomp contract states that a valid subset must govern initial send, all switch/replacement paths, exhaustion, EXP traversal, party displays and checkpoints without mutating the save party.

Observed gameplay contradicts that contract, so implementation must begin with root-cause characterization on the **exact released engine used by the player** and on current upstream `dev`.

### 10.1 Ownership rule

- If the released engine fails its own documented `playerPartyIndices` contract, fix the engine generically through the normal upstream contribution process.
- If current upstream already fixes the issue, determine the minimum released-engine version containing the correction and update the mod version floor only when necessary.
- If the engine contract is healthy and the mod is passing malformed/stale indices, fix the mod.

### 10.2 Forbidden workaround

Never enforce Gym registration by temporarily deleting, reordering or replacing `game.save.party`.

The battle-local party scope exists specifically to avoid save-state mutation and checkpoint corruption.

## 11. Progression-aware evolutions (P1)

Current non-level evolutions often use surrogate levels for NPC plausibility. Keep surrogate level as a timing heuristic, but add a separate resource/method gate where appropriate.

Examples of questions the system should be able to express later:

- Is a stone-based evolution plausible in this world phase?
- Is a trade-style evolution plausible for this trainer identity?
- Is this an explicit boss/Kanto+ exception?

Do not globally force NPC evolution resources to match the player's personal inventory.

Explicitly approved Kanto+ boss continuations remain exceptions.

## 12. Progression-aware ecology and organization windows (P1)

The ecology subsystem already uses real encounter data and limited map adjacency. Story barriers can still make topologically adjacent data fictionally unreachable.

Later work should allow `world_progression` to filter ecology traversal through known progression gates such as story doors, guards and HM-enabled routes where public data can express them reliably.

Organization-issued classes (`ROCKET`, `SCIENTIST`, `SUPER_NERD`) should also gain explicit progression windows so a class-level issued pool cannot accidentally import much later organization resources solely because they exist in trainer data.

These improvements are lower priority than TM legality and Gym scope, but they should reuse the same authority instead of inventing separate badge rules.

## 13. Diagnostics and evidence

Developer diagnostics must expose enough information to explain surprising outcomes without dumping private or ROM-derived data.

Recommended fields:

- `progressionEpoch`
- `worldMilestones`
- `moveProvenance`
- `rejectedMoveCandidates` with reason codes
- `movesetTier`
- `tacticalTier`
- `bossExceptionsApplied`
- `registeredPartyIndices`
- `battleScopedPartyCount`

Reason codes should be stable and machine-readable, for example:

- `tm-source-not-yet-world-available`
- `unique-reward-milestone-incomplete`
- `moveset-tier-cap`
- `species-incompatible`
- `identity-exception`
- `kanto-plus-unavailable`

Do not log player move lists as countering evidence.

## 14. Testing strategy

Every behavior change follows TDD. The first test for each observed defect must fail for the intended reason.

Mandatory test layers:

### Unit

- world snapshot normalization;
- resource availability by version/milestone;
- TM provenance lookup;
- moveset legal-pool filtering;
- moveset-tier caps independent of tactical tier;
- migration idempotence;
- Oak encounter classification.

### Property

- world progression is monotone;
- a resource never becomes legal before its source;
- player species/moves do not affect resource legality;
- same seed + same world snapshot gives same moveset;
- migration preserves identity/history;
- progression refresh occurs at most once per epoch.

### Integration

- standard trainer before/after a TM unlock;
- Rival Route 22 with T3 tactics but early legal resources only;
- Oak exact vanilla parity;
- Gym registration subset across manual switch, Shift prompt, forced replacement and exhaustion;
- checkpoint restore with scoped Gym party;
- boss signature exception;
- Kanto-only fallback;
- Red/Blue/Yellow resource tables.

### Engine regression when required

- no-mod parity;
- scoped party initial send;
- voluntary switch;
- forced replacement;
- exhaustion/blackout;
- EXP traversal;
- ball/UI traversal;
- checkpoint capture/restore;
- malformed-scope fallback;
- save-party object identity unchanged.

### Real-data acceptance

Repeat the real Blue + Gold sidecar acceptance used for v0.1.0 after implementation. Add sanitized scenarios for:

- Oak vanilla Rival;
- early Route 22 Rival without impossible TM;
- Brock 3-player-party -> register 2 -> third inaccessible -> registered pair faint -> loss;
- a later unlock causing a legal progression refresh;
- Kanto+ boss exception still functioning.

## 15. Release and compatibility policy

This work changes core interpretation of generated resources and challenge participation and should be released as a feature-level pre-1.0 increment (recommended target: `0.2.0`, subject to repository versioning decision at execution time).

Release gates remain the existing strict package/reproducibility/ROM-free gates plus the new integrity acceptance scenarios.

Do not submit or update the mod-index listing until the resulting release has been manually tested and explicitly approved by the human owner.

## 16. Non-goals

Do not build:

- a full NPC economy;
- per-NPC money balances;
- simulated shopping trips;
- consumable TM inventory bookkeeping for every NPC;
- player-inventory mirroring;
- player-species or player-move counter-picking;
- a universal rule that NPC species must follow the player's acquisition timeline;
- an Aerodactyl/Brock progression restriction;
- save-party mutation as a Gym-scoping workaround.

## 17. Workstream decomposition

Implementation is deliberately split into four plans so each can be reviewed and proven independently:

1. `docs/superpowers/plans/2026-08-25-gym-battle-participation-integrity.md`
2. `docs/superpowers/plans/2026-08-25-oaks-lab-vanilla-sanctuary.md`
3. `docs/superpowers/plans/2026-08-25-world-progression-moveset-integrity.md`
4. `docs/superpowers/plans/2026-08-25-progression-reachability-integrity.md`

The execution order is 1 -> 2 -> 3 -> 4. Workstream 4 is P1 and may be deferred from the first corrective release only if the release notes and agentic handoff explicitly record that deferral. Workstreams 1-3 are release-blocking.

## 18. Acceptance statement

The design is complete when a future agent can answer every surprising trainer capability with one of three explanations:

1. **vanilla/world progression permits it**;
2. **trainer identity explicitly permits it**;
3. **an approved Adaptive/Kanto+ exception explicitly permits it**.

And every Gym registration restriction must be enforced by the actual battle-local party authority from battle construction through defeat/checkpoint completion.