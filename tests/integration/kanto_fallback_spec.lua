local ROOT = assert(os.getenv("ADAPTIVE_TRAINERS_ROOT"),
  "ADAPTIVE_TRAINERS_ROOT must name the standalone mod checkout")

local kanto_plus = assert(loadfile(ROOT .. "/src/data/kanto_plus.lua"))()

local checks, failures = 0, 0
local function check(condition, message)
  checks = checks + 1
  if not condition then failures = failures + 1; io.stderr:write("FAIL ", message, "\n") end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
  return out
end

local instance = {
  id = "brock-signature", lineId = "ONIX_LINE", species = "STEELIX",
  level = 42, moves = { "IRON_TAIL", "EARTHQUAKE", "ROCK_SLIDE" },
  attachment = 77,
}
local changed = kanto_plus.reconcile_instance(instance, { ONIX = {} })
eq(changed, true, "missing sidecar content triggers a safe fallback")
eq(instance.species, "ONIX", "Steelix falls back to the prior Kanto stage")
eq(instance.lineId, "ONIX_LINE", "fallback never rerolls line identity")
eq(instance.level, 42, "fallback preserves the generated level")
eq(instance.attachment, 77, "fallback preserves unrelated persistent state")
eq(instance.suspendedStage.species, "STEELIX",
  "fallback remembers the unavailable post-Gen1 stage")
eq(instance.suspendedStage.fallback, "ONIX",
  "fallback records the concrete Kanto replacement")

local unchanged = kanto_plus.reconcile_instance(instance, { ONIX = {} })
eq(unchanged, false, "repeated fallback reconciliation is idempotent")
eq(instance.suspendedStage.species, "STEELIX",
  "repeated fallback does not overwrite restoration memory")

local restored = kanto_plus.reconcile_instance(instance, {
  ONIX = {}, STEELIX = {},
})
eq(restored, true, "restored sidecar content reverses the suspension")
eq(instance.species, "STEELIX", "the original post-Gen1 stage returns")
eq(instance.suspendedStage, nil, "successful restoration clears the marker")
eq(table.concat(instance.moves, ","),
  "IRON_TAIL,EARTHQUAKE,ROCK_SLIDE",
  "suspension preserves persistent move memory byte-for-byte")

local ordinary = { id = "ordinary", lineId = "ZUBAT_LINE",
  species = "GOLBAT", level = 35 }
eq(kanto_plus.reconcile_instance(ordinary, { GOLBAT = {} }), false,
  "Kanto-only individuals remain byte-stable without the sidecar")
eq(ordinary.suspendedStage, nil,
  "ordinary Kanto stages never gain a false suspension marker")

local drifted = { species = "ONIX", lineId = "ONIX_LINE",
  suspendedStage = { species = "STEELIX", fallback = "GOLBAT" } }
eq(kanto_plus.reconcile_instance(drifted, { ONIX = {}, STEELIX = {} }), false,
  "a malformed marker fails closed instead of changing evolution lines")
eq(drifted.species, "ONIX", "failed restoration leaves the live stage intact")

local evolutionCases = {
  { "ZUBAT_LINE", "GOLBAT", "CROBAT", 36 },
  { "ODDISH_LINE", "GLOOM", "BELLOSSOM", 36 },
  { "POLIWAG_LINE", "POLIWHIRL", "POLITOED", 36 },
  { "SLOWPOKE_LINE", "SLOWPOKE", "SLOWKING", 40 },
  { "ONIX_LINE", "ONIX", "STEELIX", 36 },
  { "SCYTHER_LINE", "SCYTHER", "SCIZOR", 36 },
  { "HORSEA_LINE", "SEADRA", "KINGDRA", 40 },
  { "PORYGON_LINE", "PORYGON", "PORYGON2", 36 },
  { "CHANSEY_LINE", "CHANSEY", "BLISSEY", 40 },
}
local allKanto, allKantoPlus, persistedOwned = {}, {}, {}
for index, row in ipairs(evolutionCases) do
  allKanto[row[2]] = {}
  allKantoPlus[row[2]] = {}
  allKantoPlus[row[3]] = {}
  persistedOwned[index] = {
    id = "persisted:" .. row[3], lineId = row[1], species = row[3],
    level = row[4], roleSeed = 1000 + index,
    unrelated = { attachment = index * 7, origin = "fixture" },
  }
end
local allRoot = { trainers = { persisted = { owned = persistedOwned } } }
local allDowngraded = kanto_plus.reconcile_root(allRoot, allKanto)
eq(allDowngraded.downgraded, 9,
  "capability loss downgrades all nine named post-Gen1 evolutions")
eq(allDowngraded.instances, 9,
  "each persisted post-Gen1 individual is reconciled exactly once")
for index, row in ipairs(evolutionCases) do
  local value = allRoot.trainers.persisted.owned[index]
  eq(value.species, row[2], row[3] .. " downgrades to its exact Kanto stage")
  eq(value.id, "persisted:" .. row[3], row[3] .. " preserves identity")
  eq(value.lineId, row[1], row[3] .. " preserves evolution-line authority")
  eq(value.level, row[4], row[3] .. " preserves level")
  eq(value.roleSeed, 1000 + index, row[3] .. " preserves deterministic seed")
  eq(value.unrelated.attachment, index * 7,
    row[3] .. " preserves unrelated nested state")
  eq(value.suspendedStage.species, row[3],
    row[3] .. " persists its exact restoration target")
end
local downgradeReplay = kanto_plus.reconcile_root(allRoot, allKanto)
eq(downgradeReplay.changed, false,
  "replaying the nine-species downgrade is idempotent")
eq(downgradeReplay.instances, 0,
  "an idempotent downgrade replay records no phantom writes")

local reloadedRoot = copy(allRoot)
local allRestored = kanto_plus.reconcile_root(reloadedRoot, allKantoPlus)
eq(allRestored.restored, 9,
  "a persisted reload restores all nine named post-Gen1 evolutions")
for index, row in ipairs(evolutionCases) do
  local value = reloadedRoot.trainers.persisted.owned[index]
  eq(value.species, row[3], row[3] .. " restores after save-shaped reload")
  eq(value.id, "persisted:" .. row[3], row[3] .. " keeps identity on restore")
  eq(value.lineId, row[1], row[3] .. " keeps line authority on restore")
  eq(value.level, row[4], row[3] .. " keeps level on restore")
  eq(value.roleSeed, 1000 + index, row[3] .. " keeps deterministic seed")
  eq(value.unrelated.origin, "fixture",
    row[3] .. " keeps unrelated nested data on restore")
  eq(value.suspendedStage, nil, row[3] .. " clears only its suspension marker")
end
local restoreReplay = kanto_plus.reconcile_root(reloadedRoot, allKantoPlus)
eq(restoreReplay.changed, false,
  "replaying the nine-species restore is idempotent")
eq(restoreReplay.instances, 0,
  "an idempotent restore replay records no phantom writes")

local runtimeMoves = { EARTHQUAKE = {}, ROCK_SLIDE = {}, TACKLE = {} }
local root = {
  trainers = { route = { owned = {
    { id = "trainer", lineId = "ZUBAT_LINE", species = "CROBAT",
      moves = { "SLUDGE_BOMB", "TACKLE" } },
  } } },
  bossAttempts = { BROCK = { party = {
    { id = "boss", lineId = "ONIX_LINE", species = "STEELIX",
      moves = { "IRON_TAIL", "EARTHQUAKE", "ROCK_SLIDE" } },
  } } },
  rival = { owned = {
    { id = "rival", lineId = "HORSEA_LINE", species = "KINGDRA",
      moves = { "SURF", "RAIN_DANCE" } },
  }, pending = { partyIds = { "rival" }, partyDef = {
    { species = "KINGDRA", level = 50, moves = { "SURF", "RAIN_DANCE" } },
  } } },
  leagueRun = { generatedParties = { BRUNO = {
    { id = "league", lineId = "ONIX_LINE", species = "STEELIX",
      moves = { "IRON_TAIL", "EARTHQUAKE" } },
  } } },
}
local kantoPokemon = {
  GOLBAT = {}, ONIX = {}, SEADRA = {},
}
local report = kanto_plus.reconcile_root(root, kantoPokemon, runtimeMoves,
  false)
eq(report.changed, true,
  "root reconciliation reports persisted capability downgrade work")
eq(root.trainers.route.owned[1].species, "GOLBAT",
  "standard trainer state downgrades through its owned roster")
eq(root.bossAttempts.BROCK.party[1].species, "ONIX",
  "boss attempt state downgrades through its persisted party")
eq(root.rival.owned[1].species, "SEADRA",
  "Rival owned state downgrades through the same line-preserving path")
eq(root.rival.pending.partyDef[1].species, "SEADRA",
  "Rival pending partyDef is synchronized before it can reach runtime")
eq(root.leagueRun.generatedParties.BRUNO[1].species, "ONIX",
  "League generated party state downgrades before materialization")
eq(table.concat(root.bossAttempts.BROCK.party[1].moves, ","),
  "EARTHQUAKE,ROCK_SLIDE",
  "unavailable sidecar move ids cannot reach a runtime party definition")
check(root.bossAttempts.BROCK.party[1].suspendedMoves ~= nil,
  "filtered move memory remains reversible in mod.save")

local restoredPokemon = {
  GOLBAT = {}, CROBAT = {}, ONIX = {}, STEELIX = {},
  SEADRA = {}, KINGDRA = {},
}
local restoredMoves = {
  TACKLE = {}, SLUDGE_BOMB = {}, IRON_TAIL = {}, EARTHQUAKE = {},
  ROCK_SLIDE = {}, SURF = {}, RAIN_DANCE = {},
}
local restoredReport = kanto_plus.reconcile_root(root, restoredPokemon,
  restoredMoves, true)
eq(restoredReport.changed, true,
  "root reconciliation reports restored capability state")
eq(root.trainers.route.owned[1].species, "CROBAT",
  "standard trainer post-Gen1 stage restores")
eq(root.bossAttempts.BROCK.party[1].species, "STEELIX",
  "boss post-Gen1 stage restores")
eq(root.rival.pending.partyDef[1].species, "KINGDRA",
  "Rival pending partyDef restores from owned authority")
eq(table.concat(root.bossAttempts.BROCK.party[1].moves, ","),
  "IRON_TAIL,EARTHQUAKE,ROCK_SLIDE",
  "sidecar move memory restores byte-for-byte when ids return")

if failures > 0 then
  io.stderr:write(string.format("%d/%d fallback checks failed\n", failures, checks))
  os.exit(1)
end
print(string.format("%d/%d fallback checks passed", checks, checks))
